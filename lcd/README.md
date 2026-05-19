# ST7735S 健康坐姿 LCD 显示系统说明

本目录是一套基于 Verilog-2001 的 LCD 显示系统，用于 Xilinx Artix-7 / EGO1 FPGA，驱动 1.44 inch、128x128、ST7735S 控制器的 TFT LCD。LCD 通信方式为 4-wire SPI，只写不读，像素格式为 RGB565。

系统显示内容包括日期、时间、座位状态、学习计时、离座计时、HP 数值和 HP 横向血条。

## 文件关系

顶层文件是 `health_lcd_top.v`。它把 RTC、座位状态机、HP 计算、超声波测距、LCD 初始化、LCD 渲染和 SPI 字节发送模块连接起来。

```text
health_lcd_top.v
├── rtc_clock.v          产生 1 Hz tick，并维护年月日时分秒
├── seat_fsm.v           维护座位状态、学习时间和离座时间
├── ../超声波/top_Ranging.v  驱动超声波模块并输出距离
├── hp_engine.v          根据距离和入座状态更新 HP
├── st7735_init.v        复位并初始化 ST7735S LCD
├── display_renderer.v   生成整屏 128x128 RGB565 显示数据
│   └── font_rom.v       8x8 ASCII 字模 ROM
└── st7735_spi.v         低层 SPI 8-bit 字节发送器
```

`st7735_init.v` 和 `display_renderer.v` 都会向 SPI 模块发起发送请求，但二者不会同时工作。顶层用 `init_done` 做仲裁：

```verilog
assign spi_start_mux = init_done ? render_spi_start : init_spi_start;
assign spi_dc_mux    = init_done ? render_spi_dc    : init_spi_dc;
assign spi_data_mux  = init_done ? render_spi_data  : init_spi_data;
```

系统启动后先执行 LCD 初始化；初始化完成后，SPI 通道切换给显示渲染模块，开始周期性刷新整屏。

## 顶层模块

当前顶层接口在 `health_lcd_top.v` 中定义如下：

```verilog
module health_lcd_top #(
    parameter integer CLK_HZ      = 100000000,
    parameter integer SPI_CLK_DIV = 5,
    parameter integer FRAME_HZ    = 2,
    parameter integer INIT_YEAR   = 2026,
    parameter integer INIT_MONTH  = 1,
    parameter integer INIT_DAY    = 1,
    parameter integer INIT_HOUR   = 0,
    parameter integer INIT_MIN    = 0,
    parameter integer INIT_SEC    = 0,
    parameter [7:0]   MADCTL_PARAM = 8'h00,
    parameter [15:0]  LCD_X_OFFSET = 16'd2,
    parameter [15:0]  LCD_Y_OFFSET = 16'd1
)(
    input  wire clk,
    input  wire rst_n,
    input  wire pressure_ok,
    input  wire ir_ok,
    input  wire ultrasonic_echo,
    input  wire sim_fast,
    output wire ultrasonic_trig,
    output wire lcd_cs_n,
    output wire lcd_rst_n,
    output wire lcd_dc,
    output wire lcd_scl,
    output wire lcd_mosi,
    output wire lcd_blk
);
```

端口说明：

| 端口名 | 方向 | 位宽 | 说明 |
|---|---:|---:|---|
| `clk` | input | 1 | 系统主时钟。所有模块都在这个时钟下同步运行。上板使用 100 MHz 时，应把 `CLK_HZ` 参数设为 `100000000`。 |
| `rst_n` | input | 1 | 全局低有效复位。为 0 时，RTC、座位状态机、HP、LCD 初始化流程和 SPI 发送器全部回到初始状态。 |
| `pressure_ok` | input | 1 | 压力传感器判断结果。为 1 表示压力条件满足。 |
| `ir_ok` | input | 1 | 红外传感器判断结果。为 1 表示红外条件满足。 |
| `ultrasonic_echo` | input | 1 | 超声波模块的 Echo 输入。Echo 高电平宽度代表超声波往返时间，内部测距模块据此计算距离。 |
| `sim_fast` | input | 1 | 仿真加速开关。为 1 时，`seat_fsm.v` 和 `hp_engine.v` 把 1 秒当作 1 分钟；上板时应接 0。 |
| `ultrasonic_trig` | output | 1 | 超声波模块的 Trig 输出。顶层内部周期性产生触发脉冲，让超声波模块开始一次测距。 |
| `lcd_cs_n` | output | 1 | LCD SPI 片选，低有效。发送一个字节期间拉低。 |
| `lcd_rst_n` | output | 1 | LCD 硬件复位，低有效。由 `st7735_init.v` 控制。 |
| `lcd_dc` | output | 1 | LCD 命令/数据选择。0 表示 command，1 表示 data。 |
| `lcd_scl` | output | 1 | LCD SPI 时钟。`SPI_CLK_DIV=5` 且 `clk=100MHz` 时约为 10 MHz。 |
| `lcd_mosi` | output | 1 | LCD SPI 数据线，MSB first，只写。 |
| `lcd_blk` | output | 1 | LCD 背光控制。当前固定输出 1，默认背光高有效。 |

顶层内部把压力和红外两个判断合成入座信号：

```verilog
assign seated = pressure_ok & ir_ok;
```

只有两个输入都为 1，系统才认为用户处于入座状态。`seated` 同时送到 `seat_fsm.v` 和 `hp_engine.v`。

距离不再由外部 `distance_cm` 输入直接给出，而是由内部超声波测距子系统产生：

```verilog
top_Ranging u_ultrasonic (...);
```

`top_Ranging` 输出 16-bit `ultrasonic_distance_cm`。LCD 显示和 HP 计算使用截位/饱和后的 10-bit `posture_distance_cm`：

```verilog
assign posture_distance_cm =
    (ultrasonic_distance_cm > 16'd1023) ? 10'd1023 : ultrasonic_distance_cm[9:0];
```

## 参数说明

| 参数 | 当前默认值 | 用途 |
|---|---:|---|
| `CLK_HZ` | `100000000` | 系统时钟频率参数。EGO1 使用 100 MHz 时钟时保持默认值即可。testbench 中会覆盖成较小数值以加快 LCD/RTC 仿真。 |
| `SPI_CLK_DIV` | `5` | SPI SCL 半周期分频值。SCL 频率约等于 `CLK_HZ / (2 * SPI_CLK_DIV)`。 |
| `FRAME_HZ` | `2` | LCD 整屏刷新目标帧率。 |
| `INIT_YEAR` 等 | 见代码 | RTC 复位后的初始时间。 |
| `MADCTL_PARAM` | `8'h00` | ST7735S 屏幕方向参数。方向不对时优先改这个值。 |
| `LCD_X_OFFSET` | `16'd2` | LCD GRAM 列地址偏移。当前用于修正画面向左偏 2 个像素的问题。 |
| `LCD_Y_OFFSET` | `16'd1` | LCD GRAM 行地址偏移。当前用于修正画面向上偏 1 个像素的问题。 |

## LCD 画面偏移修正

如果实际 LCD 上显示画面整体向左或向上偏移，通常不是 `pix_x/pix_y` 的像素扫描写错，而是 ST7735S 模组的可视区域和控制器内部 GRAM 地址原点有偏移。

当前代码原本按下面的窗口写屏：

```text
CASET 0..127
RASET 0..127
```

屏幕实际表现为画面向左偏 2 个像素、向上偏 1 个像素，因此需要把 LCD 写入窗口改成：

```text
CASET 2..129
RASET 1..128
```

对应参数就是：

```verilog
parameter [15:0] LCD_X_OFFSET = 16'd2;
parameter [15:0] LCD_Y_OFFSET = 16'd1;
```

这两个参数同时传给：

- `st7735_init.v`：初始化阶段设置一次窗口，保持配置一致。
- `display_renderer.v`：每一帧刷新前重新发送 `CASET/RASET/RAMWR`，这是实际决定画面位置的地方。

如果后续换了另一个 ST7735S 模组，偏移可能不同。调整原则是：

- 画面向左偏 N 个像素：增大 `LCD_X_OFFSET` N。
- 画面向上偏 N 个像素：增大 `LCD_Y_OFFSET` N。
- 画面向右偏 N 个像素：减小 `LCD_X_OFFSET` N。
- 画面向下偏 N 个像素：减小 `LCD_Y_OFFSET` N。

## 各文件功能

## rtc_clock.v

`rtc_clock.v` 负责产生 `tick_1hz`，并维护当前日期时间。

实现方式：

- `div_cnt` 从 0 计数到 `CLK_HZ-1`。
- 计满后输出一个时钟周期的 `tick_1hz`。
- 每次 `tick_1hz` 到来时，调用 `step_one_second` 推进 1 秒。
- 秒、分、时、日、月、年逐级进位。
- `days_in_month` 判断每个月天数。
- `is_leap_year` 支持闰年判断。

输出包括：

```text
year, month, day, hour, minute, second
```

这些时间信号会直接送到 `display_renderer.v`，用于显示日期和时间。

## seat_fsm.v

`seat_fsm.v` 维护座位状态机。

状态编码：

```text
0 = ST_IDLE           空闲，座位没有归属
1 = ST_STUDY          学习中
2 = ST_SEDENTARY      久坐
3 = ST_OVER_SEDENTARY 过度久坐
4 = ST_REST           休息 / 中途离开
5 = ST_AWAY_LONG      长时间离开
```

核心规则：

- 坐下后开始计时，进入 `ST_STUDY`。
- 坐下时间达到 45 分钟后进入 `ST_SEDENTARY`。
- 坐下时间达到 60 分钟后进入 `ST_OVER_SEDENTARY`。
- 中途离开后进入 `ST_REST`，并开始累计 `away_time_min`。
- 离开时间超过 3 分钟后再回来，认为是有效休息，清空 `sit_time_min`，重新开始学习计时。
- 离开 3 分钟内回来，不认为是有效休息，继续之前的 `sit_time_min`。
- 离开达到 20 分钟进入 `ST_AWAY_LONG`。
- 离开达到 30 分钟进入 `ST_IDLE`，清空座位所有权和学习计时。

计时输出分为分钟和秒：

```text
sit_time_min / sit_time_sec   当前连续学习/入座时间
away_time_min / away_time_sec 当前离座时间
```

这些秒级输出只用于显示精度。45/60/20/30 分钟的状态阈值仍按分钟边界判断。

`sim_fast=1` 时，每个 `tick_1hz` 都当作 1 分钟；`sim_fast=0` 时，累计 60 个 `tick_1hz` 才产生 1 个分钟更新。

注意：`sim_fast=1` 是为了快速仿真，秒字段固定为 `00`；上板时 `sim_fast=0`，`SIT/AWAY/NOW` 才会显示真实秒数。

## hp_engine.v

`hp_engine.v` 根据入座状态和距离更新 HP。

输出：

- `hp`：0 到 100，饱和加减。
- `hp_zero_alarm`：HP 为 0 时拉高。
- `posture_level`：坐姿等级。

规则：

```text
seated=0：HP 不更新
seated=1 且 posture_distance_cm > 50：每分钟 HP +1，最大 100
seated=1 且 30 <= posture_distance_cm <= 50：每分钟 HP -1，最小 0
seated=1 且 posture_distance_cm < 30：每分钟 HP -3，最小 0
```

坐姿等级：

```text
0 = SAFE
1 = WARN
2 = DANGER
```

和 `seat_fsm.v` 一样，`sim_fast=1` 用于快速仿真。

## st7735_spi.v

`st7735_spi.v` 是底层 SPI 发送模块。它一次只发送 1 个 8-bit 字节。

接口行为：

- `start=1` 且模块空闲时，锁存 `dc` 和 `data`。
- `lcd_cs_n` 拉低，开始发送。
- `lcd_dc` 输出当前字节类型。
- `lcd_mosi` 按 MSB first 输出。
- `lcd_scl` 按 `SPI_CLK_DIV` 分频翻转。
- 8 bit 发送完成后，`lcd_cs_n` 拉高，`done` 输出一个时钟周期。

`dc` 的含义：

```text
dc = 0：当前字节是 LCD command
dc = 1：当前字节是 LCD data
```

## st7735_init.v

`st7735_init.v` 负责 LCD 上电初始化。

流程：

1. 拉低 `lcd_rst_n`，保持复位。
2. 拉高 `lcd_rst_n`，等待 LCD 内部稳定。
3. 通过 SPI 发送初始化命令。
4. 完成后输出 `init_done=1`。

初始化序列：

```text
0x01              SWRESET
0x11              SLPOUT
0x3A, 0x05        COLMOD，设置 RGB565
0x36, MADCTL      MADCTL，设置方向
0x2A, 0,0,0,127   CASET，列地址 0..127
0x2B, 0,0,0,127   RASET，行地址 0..127
0x13              NORON
0x29              DISPON
```

`seq_data(seq_idx)` 保存每一步要发送的字节，`seq_dc(seq_idx)` 指出该字节是命令还是数据，`delay_after(seq_idx)` 在关键命令后插入等待时间。

## font_rom.v

`font_rom.v` 是组合逻辑字模 ROM。

输入：

```text
ascii：要显示的 ASCII 字符
row：该字符内部第几行，范围 0..7
```

输出：

```text
bits：该行 8 个像素的点阵数据
```

例如 `bits[7]` 对应字符最左侧像素，`bits[0]` 对应字符最右侧像素。`display_renderer.v` 用它判断当前像素是不是文字笔画。

当前字库只覆盖界面需要的字符：数字、空格、`-`、`:` 和界面用到的大写字母，例如 `A/C/D/E/F/G/H/I/L/M/N/O/P/R/S/T/U/V/W/Y`。未覆盖字符会显示为方框，便于发现缺字。

## LCD 显示渲染输出

本节对应 `display_renderer.v`，它是 LCD 画面生成的核心。

### 渲染模块输入输出

输入信号分为三类：

| 类型 | 信号 | 作用 |
|---|---|---|
| 控制 | `clk`, `rst_n`, `init_done` | 控制渲染状态机运行。只有 `init_done=1` 后才刷新画面。 |
| SPI 握手 | `spi_busy`, `spi_done` | 和 `st7735_spi.v` 做字节发送握手。 |
| 显示数据 | `year/month/day/hour/minute/second` | 显示日期和时间。 |
| 显示数据 | `seat_state` | 显示状态字符串。 |
| 显示数据 | `posture_level` | 显示姿势状态字符串，和久坐状态分开。 |
| 显示数据 | `sit_time_min/sit_time_sec`, `away_time_min/away_time_sec` | 显示学习时间、离座时间和当前状态计时器，格式为 `mmmm:ss`。 |
| 显示数据 | `distance_cm` | 显示当前超声波距离，格式为 `DIST xxxxCM`。 |
| 显示数据 | `hp`, `hp_zero_alarm` | 显示 HP 数值、血条颜色和报警闪烁。 |

输出给 SPI 的信号：

| 信号 | 作用 |
|---|---|
| `spi_start` | 请求发送一个字节。 |
| `spi_dc` | 当前字节是命令还是数据。 |
| `spi_data` | 当前要发送的 8-bit 字节。 |

渲染模块不直接驱动 LCD 引脚，它只产生 SPI 字节请求。真正的引脚波形仍由 `st7735_spi.v` 输出。

### 屏幕坐标和像素扫描

LCD 分辨率是 128x128。渲染器内部用两个 7-bit 计数器扫描全屏：

```verilog
reg [6:0] pix_x;
reg [6:0] pix_y;
```

扫描顺序是从左到右、从上到下：

```text
(0,0)   -> (1,0)   -> ... -> (127,0)
(0,1)   -> (1,1)   -> ... -> (127,1)
...
(0,127) -> (1,127) -> ... -> (127,127)
```

每个像素生成一个 16-bit RGB565 颜色：

```verilog
reg [15:0] pixel_rgb;
```

随后分两次通过 SPI 发给 LCD：

```text
先发 pixel_rgb[15:8]
再发 pixel_rgb[7:0]
```

因此一帧完整画面需要发送：

```text
128 * 128 = 16384 个像素
16384 * 2 = 32768 个像素数据字节
```

### 一帧刷新流程

渲染状态机有 5 个状态：

```text
R_IDLE      等待下一帧刷新时间
R_SEQ_SEND  发送窗口设置命令或数据
R_SEQ_WAIT  等待当前窗口设置字节发送完成
R_PIX_SEND  发送当前像素的高字节或低字节
R_PIX_WAIT  等待当前像素字节发送完成
```

完整流程：

1. `R_IDLE` 中等待 `FRAME_PERIOD = CLK_HZ / FRAME_HZ`。
2. 到达刷新周期后，发送窗口设置序列。
3. 设置列地址 `CASET 0..127`。
4. 设置行地址 `RASET 0..127`。
5. 发送 `RAMWR 0x2C`，告诉 LCD 后续是显存像素数据。
6. 从 `(0,0)` 开始逐像素生成 `pixel_rgb`。
7. 每个像素发高字节、低字节。
8. 扫到 `(127,127)` 后一帧结束，回到 `R_IDLE`。

窗口设置字节由 `seq_data(seq_idx)` 和 `seq_dc(seq_idx)` 给出：

```text
idx 0：0x2A，command，CASET
idx 1：0x00，data，起始列高字节
idx 2：0x00，data，起始列低字节
idx 3：0x00，data，结束列高字节
idx 4：0x7F，data，结束列低字节，127
idx 5：0x2B，command，RASET
idx 6：0x00，data，起始行高字节
idx 7：0x00，data，起始行低字节
idx 8：0x00，data，结束行高字节
idx 9：0x7F，data，结束行低字节，127
idx 10：0x2C，command，RAMWR
```

### 屏幕布局

屏幕被当作 16 列 x 16 行的 8x8 字符网格，因为：

```text
128 / 8 = 16
```

当前像素对应的字符网格位置：

```verilog
cell_col = pix_x[6:3];  // 0..15
cell_row = pix_y[6:3];  // 0..15
```

字符内部像素位置：

```verilog
font_col = pix_x[2:0];  // 0..7
font_row = pix_y[2:0];  // 0..7
```

当前界面布局如下：

```text
字符行 0：YYYY-MM-DD
字符行 1：HH:MM:SS
字符行 2：空
字符行 3：STAT IDLE / STUDY / LONG / OVER / REST / AWAY
字符行 4：POST SAFE / WARN / DANGER
字符行 5：SIT 0000:00
字符行 6：AWAY 0000:00
字符行 7：空
字符行 8：NOW 0000:00
字符行 9：空
字符行 10：DIST 0060CM
字符行 11：HP 100
像素 y=112..123：HP 横向血条
其他区域：黑色背景
```

`NOW 0000:00` 是当前状态计时器：

- 状态为 `ST_STUDY`、`ST_SEDENTARY`、`ST_OVER_SEDENTARY` 时，显示当前学习/入座时间 `sit_time_min:sit_time_sec`。
- 状态为 `ST_REST`、`ST_AWAY_LONG` 时，显示当前离座时间 `away_time_min:away_time_sec`。
- 状态为 `ST_IDLE` 时，显示 `0000:00`。

`DIST 0060CM` 显示当前超声波测距值。显示宽度固定为 4 位十进制数字，因此 60 cm 会显示为 `0060CM`，最大可覆盖 LCD 渲染输入的 `1023CM`。

状态显示被拆成两类，避免“久坐”和“姿势不当”混在一个字段里：

- `STAT` 来自 `seat_fsm.v` 的 `seat_state`，描述座位/久坐状态。
- `POST` 来自 `hp_engine.v` 的 `posture_level`，描述距离导致的姿势状态。

`STAT` 状态字符串映射：

| `seat_state` | 显示字符串 |
|---:|---|
| 0 | `IDLE` |
| 1 | `STUDY` |
| 2 | `LONG` |
| 3 | `OVER` |
| 4 | `REST` |
| 5 | `AWAY` |

注意：状态 2 的内部名字是 `ST_SEDENTARY`，屏幕上为了节省宽度显示为 `LONG`。

`POST` 姿势字符串映射：

| `posture_level` | 显示字符串 | 含义 |
|---:|---|---|
| 0 | `SAFE` | `posture_distance_cm > 50`，姿势距离安全 |
| 1 | `WARN` | `30 <= posture_distance_cm <= 50`，姿势需要注意 |
| 2 | `DANGER` | `posture_distance_cm < 30`，姿势不当 |

### 文字生成方式

`char_at(cell_col, cell_row)` 根据字符网格位置返回当前格子应该显示的 ASCII 字符。例如：

- 第 0 行返回日期字符。
- 第 1 行返回时间字符。
- 第 3 行返回 `STAT ` 加状态字符串。
- 第 4 行返回 `POST ` 加姿势字符串。
- 第 5 行返回 `SIT 0000:00`。
- 第 6 行返回 `AWAY 0000:00`。
- 第 8 行返回 `NOW 0000:00`。
- 第 10 行返回 `DIST xxxxCM`。
- 第 11 行返回 `HP xxx`。

数字不是用十进制字符串库生成的，而是在硬件中用除法和取模拆成各个位：

```verilog
year_th = (year / 1000) % 10;
year_h  = (year / 100)  % 10;
year_t  = (year / 10)   % 10;
year_o  = year % 10;
```

然后 `ascii_digit()` 把 0..9 转成 ASCII `0`..`9`。

字模判断流程：

1. `char_at()` 得到当前字符的 ASCII。
2. `font_rom` 根据 ASCII 和 `font_row` 输出这一行 8 bit 点阵。
3. `text_on = font_bits[7 - font_col]` 判断当前像素是否属于文字笔画。
4. 如果 `text_on=1`，当前像素输出文字颜色。

### HP 血条生成方式

HP 血条区域是像素坐标：

```text
x = 8..119
y = 112..123
```

其中边框为白色：

```text
x=8 或 x=119 或 y=112 或 y=123
```

内部可填充宽度按 HP 比例计算：

```verilog
hp_bar_width = (hp * 110) / 100;
```

内部填充颜色：

```text
HP >= 70：绿色，RGB565 = 16'h07E0
30 <= HP < 70：黄色，RGB565 = 16'hFFE0
HP < 30：红色，RGB565 = 16'hF800
```

未填充部分是灰色：

```text
16'h4208
```

### 报警闪烁

当满足任一条件时，状态区域会闪烁：

```text
hp_zero_alarm = 1
seat_state = ST_OVER_SEDENTARY
```

闪烁节奏由 RTC 秒最低位控制：

```verilog
blink_on = (hp_zero_alarm || (seat_state == 3'd3)) && second[0];
```

当前实现是全屏闪烁，不再只闪烁状态区域。闪烁打开时：

- 全屏背景变成暗红色 `16'h6000`。
- 当前屏幕上的文字变成黄色 `16'hFFE0`。
- HP 血条在闪烁相位中暂时被全屏报警底色覆盖，用于突出报警状态。

### 像素颜色优先级

`pixel_rgb` 的组合逻辑按优先级决定当前像素颜色：

1. 如果 `blink_on=1`，全屏进入报警闪烁：文字为黄色，背景为暗红。
2. 否则，如果当前像素在 HP 血条区域，绘制血条和边框。
3. 否则，如果当前像素是文字笔画，绘制白色文字。
4. 否则绘制黑色背景。

这意味着报警闪烁优先级最高；正常显示时 HP 血条优先于普通文字和背景。

### 资源特点

当前渲染器没有使用帧缓存 RAM，而是边扫描、边计算、边发送。

优点：

- 资源占用低。
- 不需要 128x128x16 bit 的显存。
- 显示内容由寄存器实时决定。

限制：

- 每次刷新都要发送整屏 32768 字节。
- 字体和布局是固定写在逻辑里的。
- 字符显示只支持 `font_rom.v` 中已有的 ASCII 字符。

## Testbench

`tb_health_lcd_top.v` 用于验证主要逻辑。

当前 testbench 做了这些检查：

- LCD 初始化完成。
- HP 在安全、警戒、危险距离下分别按规则变化。
- HP 到 0 后饱和并触发报警。
- 坐满 45 分钟进入久坐。
- 坐满 60 分钟进入过度久坐。
- 离开 20 分钟进入长时间离开。
- 离开 30 分钟回到空闲并清空学习时间。
- 离开 3 分钟内返回，不清空学习时间。
- 离开超过 3 分钟后返回，清空学习时间并重新进入学习。

运行命令：

```powershell
cd D:\UserDate\DeskTop\数字系统Project\src\lcd
iverilog -g2001 -Wall -o tb_health_lcd_top.vvp tb_health_lcd_top.v health_lcd_top.v st7735_spi.v st7735_init.v display_renderer.v font_rom.v rtc_clock.v seat_fsm.v hp_engine.v ..\超声波\top_Ranging.v ..\超声波\trig_generator.v ..\超声波\signal_sync.v ..\超声波\distance_calc.v
vvp tb_health_lcd_top.vvp
```

通过时应看到：

```text
ALL TESTS PASSED
```

## XDC 约束

`ego1_st7735_example.xdc` 是示例约束文件。

它包含：

- `clk` 的时钟约束。
- 输入输出端口的 `LVCMOS33` I/O 标准。
- LCD、超声波和传感器管脚的占位模板。

上板前需要按实际 EGO1 板卡和 LCD 接线替换 `PACKAGE_PIN`。

## 上板注意事项

1. 在 Vivado 中把 `health_lcd_top.v` 设为顶层。
2. 添加本目录所有 `.v` 文件，以及 `../超声波` 目录下所有 `.v` 文件。
3. 修改 XDC 中的真实管脚。
4. 如果使用 EGO1 的 100 MHz 时钟，把 `CLK_HZ` 改为 `100000000`。
5. 上板时 `sim_fast` 应接 0。
6. SPI 初始频率建议 10 MHz 或更低。如果屏幕不稳定，可以增大 `SPI_CLK_DIV`。
7. 如果画面方向不对，调整 `MADCTL_PARAM`。
8. 如果背光引脚是低有效，需要把 `lcd_blk` 的固定输出从 1 改成 0，或增加背光极性参数。

## 当前实现边界

- SPI 只写，不读 LCD 状态或 ID。
- 没有帧缓存，画面实时生成。
- 字库是简化 8x8 ASCII 字库。
- RTC 没有外部校时接口。
- LCD 初始化序列是常用最小序列，不同 ST7735S 模组可能需要增加偏移、颜色顺序或厂商初始化命令。


# 称重子系统说明

本目录包含 HX711 称重读取代码，以及给健康坐姿顶层预留的四角称重重心分析接口。

## 当前接口规划

系统顶层 `lcd/health_lcd_top.v` 为称重数据预留 4 个干净的数值输入：

```verilog
input wire [15:0] weight_left_front,
input wire [15:0] weight_left_rear,
input wire [15:0] weight_right_front,
input wire [15:0] weight_right_rear
```

四个输入分别对应：

| 接口 | 含义 |
|---|---|
| `weight_left_front` | 左前称重点 |
| `weight_left_rear` | 左后称重点 |
| `weight_right_front` | 右前称重点 |
| `weight_right_rear` | 右后称重点 |

这些接口当前按“已经处理好的重量数值”接入，不直接绑定某一个 HX711 芯片引脚。后续可以由四个 HX711 读取模块、标定模块或滤波模块生成这四路数值。

## 重心分析模块

新增模块：

```text
weight_balance_analyzer.v
```

接口：

```verilog
module weight_balance_analyzer #(
    parameter [15:0] WARN_DIFF = 16'd1000,
    parameter [15:0] DANGER_DIFF = 16'd3000
)(
    input  wire [15:0] weight_left_front,
    input  wire [15:0] weight_left_rear,
    input  wire [15:0] weight_right_front,
    input  wire [15:0] weight_right_rear,
    output reg  [16:0] front_weight_sum,
    output reg  [16:0] rear_weight_sum,
    output reg  [16:0] left_weight_sum,
    output reg  [16:0] right_weight_sum,
    output reg  [16:0] front_back_diff,
    output reg  [16:0] left_right_diff,
    output reg  [1:0]  front_back_balance,
    output reg  [1:0]  left_right_balance
);
```

## 计算方式

前后分布：

```text
front_weight_sum = weight_left_front + weight_right_front
rear_weight_sum  = weight_left_rear  + weight_right_rear
front_back_diff  = abs(front_weight_sum - rear_weight_sum)
```

左右分布：

```text
left_weight_sum  = weight_left_front  + weight_left_rear
right_weight_sum = weight_right_front + weight_right_rear
left_right_diff  = abs(left_weight_sum - right_weight_sum)
```

等级输出：

```text
0 = CENTER  差值较小，重心基本居中
1 = WARN    差值超过 WARN_DIFF
2 = DANGER  差值超过 DANGER_DIFF
```

默认阈值：

```text
WARN_DIFF   = 1000
DANGER_DIFF = 3000
```

这两个阈值与实际传感器标定单位有关。若输入是 HX711 原始值，应先做去皮、滤波和标定，再根据实际量程调整阈值。

## 和系统顶层的关系

`health_lcd_top.v` 已经实例化：

```verilog
weight_balance_analyzer u_weight_balance (...);
```

并向外输出：

```verilog
output wire [16:0] weight_front_back_diff
output wire [16:0] weight_left_right_diff
output wire [1:0]  weight_front_back_balance
output wire [1:0]  weight_left_right_balance
```

这些输出目前作为干净的系统接口保留，后续可以用于 LCD 显示、HP 影响、蜂鸣器报警或上位机记录。

## 现有 HX711 文件

目录中仍保留原来的单路 HX711 串口调试链路：

```text
hx711_reader.v
hx711_uart_link.v
hx711_weight_uart_top.v
uart_tx.v
```

这些文件用于读取单个 HX711 的 24-bit 原始数据并通过串口输出，适合做传感器调试和标定。正式集成四角称重时，建议复用 `hx711_reader.v`，为四个角各实例化一路读取链路，然后把标定后的重量数值接到四个 `weight_*` 输入。

## 上板建议

1. 先分别调通每个称重点的 HX711 原始读数。
2. 对四路传感器做去皮和标定，统一单位。
3. 将四路重量数值接入 `weight_balance_analyzer.v`。
4. 根据实际坐垫结构和传感器量程调整 `WARN_DIFF`、`DANGER_DIFF`。

# 简单四角重量分析器

本目录保留一个不依赖时钟的简单组合逻辑模块：

```text
weight_balance_analyzer.v
```

它接收左前、左后、右前、右后四个 16-bit 重量值，输出前后/左右重量和、绝对差值和固定阈值等级。

## 接口

```verilog
input  wire [15:0] weight_left_front;
input  wire [15:0] weight_left_rear;
input  wire [15:0] weight_right_front;
input  wire [15:0] weight_right_rear;

output wire [16:0] front_weight_sum;
output wire [16:0] rear_weight_sum;
output wire [16:0] left_weight_sum;
output wire [16:0] right_weight_sum;
output wire [16:0] front_back_diff;
output wire [16:0] left_right_diff;
output wire [1:0]  front_back_balance;
output wire [1:0]  left_right_balance;
```

计算方式：

```text
front = LF + RF
rear  = LR + RR
left  = LF + LR
right = RF + RR

front_back_diff = abs(front - rear)
left_right_diff = abs(left - right)
```

固定阈值：

```text
前后差值：<50 正常，50..149 警告，>=150 危险
左右差值：<40 正常，40..119 警告，>=120 危险
```

## 当前使用状态

当前 `lcd/health_lcd_top.v` 不实例化本模块。它只计算四角重量绝对差值，并从外部接收重心等级和方向。

推荐双板方案使用：

```text
../two_board_weight_link/weight_board/src/seat_weight_analyzer.v
```

该模块使用相对总重量百分比判定重心，更适合不同体重和不同传感器量程。

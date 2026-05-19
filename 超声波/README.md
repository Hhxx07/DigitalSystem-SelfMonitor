# 超声波测距子系统说明

本目录是超声波测距模块，用于给 LCD 健康坐姿系统提供当前距离 `distance_cm`。距离会在 LCD 屏幕上显示为 `DIST xxxxCM`，不再通过串口重复输出。

## 硬件条件

超声波测距仪除电源接口外有两个信号接口：

| 引脚 | 方向 | 说明 |
|---|---|---|
| `Trig` | FPGA 输出到超声波模块 | 触发信号。FPGA 拉高一小段时间后，超声波模块开始发射超声波并启动测距。 |
| `Echo` | 超声波模块输出到 FPGA | 回波时间信号。Echo 高电平持续时间表示超声波从发射到接收回波的往返时间。 |

本工程假设：

- FPGA 时钟为 100 MHz。
- 复位 `rst_n/RST` 为低有效。
- `Trig` 由 FPGA 周期性产生。
- `Echo` 是异步外部输入，进入 FPGA 后先做两级同步，再做边沿检测。

如果超声波模块 Echo 电平为 5 V，而 FPGA I/O 只支持 3.3 V，必须加分压或电平转换，不能直接接入 FPGA。

## 文件组成

```text
超声波/
├── top_Ranging.v     测距子系统顶层，连接 Trig、Echo 和距离计算
├── trig_generator.v  周期性产生 Trig 触发脉冲
├── signal_sync.v     对 Echo 做同步和上升/下降沿检测
└── distance_calc.v   根据 Echo 高电平宽度计算距离，单位 cm
```

## 顶层接口

当前 `top_Ranging.v` 接口如下：

```verilog
module top_Ranging(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        ultrasonic_echo,
    output wire        ultrasonic_trig,
    output wire [15:0] distance_cm
);
```

端口说明：

| 端口 | 方向 | 说明 |
|---|---|---|
| `clk` | input | 系统时钟，默认按 100 MHz 使用。 |
| `rst_n` | input | 低有效复位。 |
| `ultrasonic_echo` | input | 接超声波模块 Echo 引脚。 |
| `ultrasonic_trig` | output | 接超声波模块 Trig 引脚。 |
| `distance_cm` | output | 测得的距离，单位 cm，16-bit 二进制。 |

## 工作流程

1. `trig_generator.v` 周期性产生 `ultrasonic_trig` 高电平脉冲。
2. 超声波模块收到 Trig 后开始测距，并在 `Echo` 输出一个高电平脉冲。
3. `signal_sync.v` 对 `Echo` 做两级同步，生成：
   - `pos_edge`：Echo 上升沿，表示开始计时。
   - `neg_edge`：Echo 下降沿，表示停止计时。
4. `distance_calc.v` 在 Echo 高电平期间计数，并换算为厘米。
5. 测距完成后，`distance_cm` 更新为最新距离。
6. LCD 顶层 `health_lcd_top.v` 使用该距离更新：
   - 姿势状态 `POST SAFE/WARN/DANGER`
   - HP 加减
   - LCD 上的 `DIST xxxxCM` 显示

## 距离计算方式

`distance_calc.v` 内部把 Echo 高电平宽度换算成距离。当前实现中：

```verilog
if (cnt_17k < 16'd5600)
    cnt_17k <= cnt_17k + 1;
else
    cnt <= cnt + 1;
```

也就是在 100 MHz 时钟下，约每 5600 个时钟周期累计 1 cm。这个系数是经验修正值，接近常见超声波往返时间换算，但已经根据实际测量做了微调。

如果测量偏差固定，可以调整 `5600`：

- 测出来距离偏小：适当增大该计数值。
- 测出来距离偏大：适当减小该计数值。

## Trig 触发方式

`trig_generator.v` 负责周期性触发测距。

当前代码逻辑：

- `cnt_trig` 周期计数。
- 周期开始的一小段时间内 `Trig=1`。
- 其余时间 `Trig=0`。

代码中计数参数基于 100 MHz：

- 触发周期计数为 `6_500_000`，约 65 ms。
- `Trig` 高电平约 `2500` 个时钟周期，约 25 us。

这对常见超声波模块是合理的：触发脉冲通常要求大于 10 us，测距周期不要过快。

## 和 LCD 顶层的关系

`health_lcd_top.v` 实例化本目录的 `top_Ranging.v`：

```verilog
top_Ranging u_ultrasonic (
    .clk(clk),
    .rst_n(rst_n),
    .ultrasonic_echo(ultrasonic_echo),
    .ultrasonic_trig(ultrasonic_trig),
    .distance_cm(ultrasonic_distance_cm)
);
```

为了兼容 LCD 显示和 HP 模块的 10-bit 距离接口，顶层会把 16-bit 距离做饱和：

```verilog
assign posture_distance_cm =
    (ultrasonic_distance_cm > 16'd1023) ? 10'd1023 : ultrasonic_distance_cm[9:0];
```

因此 LCD 显示和 HP 判断使用 0 到 1023 cm 范围。

## 上板连接建议

连接超声波模块时：

- FPGA `ultrasonic_trig` 接模块 `Trig`。
- FPGA `ultrasonic_echo` 接模块 `Echo`。
- FPGA GND 必须和超声波模块 GND 共地。
- 如果 Echo 是 5 V 电平，必须通过分压或电平转换接入 FPGA。

Vivado 工程中需要加入本目录所有 `.v` 文件，并在 XDC 中约束：

```tcl
set_property IOSTANDARD LVCMOS33 [get_ports ultrasonic_echo]
set_property IOSTANDARD LVCMOS33 [get_ports ultrasonic_trig]
```

具体 `PACKAGE_PIN` 按实际 EGO1 接线填写。


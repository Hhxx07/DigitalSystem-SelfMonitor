# 超声波测距子系统说明

本目录是超声波测距模块，用于给 LCD 健康坐姿系统提供距离数据。当前系统使用三路超声波：正前方专门测量头部/上身离桌距离，左右前方传感器测量左右胸前/肩前硬面的斜距，并用左右差值和单侧过近情况判断躯干状态。

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
├── distance_calc.v   根据 Echo 高电平宽度计算距离，单位 cm
└── torso_posture_analyzer.v 根据左右 45 度斜距判断躯干状态和 HP 额外扣分
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
6. LCD 顶层 `health_lcd_top.v` 实例化三份 `top_Ranging.v`：
   - 正前方：`ultrasonic_front_echo/trig`
   - 左前 45 度：`ultrasonic_left45_echo/trig`
   - 右前 45 度：`ultrasonic_right45_echo/trig`
7. 正前方距离作为 `dHead` 使用，用于 `POST SAFE/WARN/DANGER`、HP 基础加减和 `HEAD xxxxCM` 显示。
8. 左右 45 度距离作为 `dL/dR` 进入 `torso_posture_analyzer.v`，计算左右差值、单侧过近状态和躯干状态。

## 躯干状态判断

`torso_posture_analyzer.v` 输入三路距离：

```text
front_distance_cm
left45_distance_cm
right45_distance_cm
```

当前判断使用左右 45 度斜距：

```text
dL = left45_distance_cm
dR = right45_distance_cm
shoulder_diff_cm = abs(dL - dR)
```

安装和测量假设：

- 左右传感器水平朝桌子中线内收约 8 度。
- 左右传感器垂直方向微上仰约 3 度。
- 正常坐正时，`dL/dR` 通常在 24 到 30 cm。
- 正前方头部距离传感器位于桌子中线靠前位置，建议桌面以上约 40 cm、相对桌前沿后退约 6 cm。
- 正前方传感器向下俯角约 25 到 35 度，使波束中心落在肩心/额头中上部。
- 正常读写/屏幕坐姿下，`dHead` 通常约 28 到 42 cm。

`torso_posture_analyzer.v` 的默认稳定时间为 `STABLE_MS=500`，也就是异常条件需要持续约 0.5 秒才改变躯干状态。需要更灵敏时可把该参数改为 300。

左右 45 度躯干判断阈值：

| 差值范围 | 显示 | 含义 | HP 额外影响 |
|---|---|---|---:|
| `dL/dR` 都在 24..30cm，且 `abs(dL-dR) < 5cm` | `GOOD` | 躯干基本正常 | 0 |
| 任一侧离开 24..30cm 正常范围，且未触发更严重条件 | `LEAN` | 微倾或轻微偏位 | 每分钟 -1 |
| 任一侧 `< 19cm` 且稳定 | `SIDE` | 这一侧太贴近桌沿，侧弯/侧倾过大 | 每分钟 -2 |
| `abs(dL-dR) >= 5cm` 且稳定，且没有单侧过近 | `TWIST` | 左右肩前斜距不均，疑似扭转/歪坐 | 每分钟 -3 |

正前方 `dHead` 不在 `torso_hp_penalty` 中重复扣分，而是由 `hp_engine.v` 直接产生 `POST` 状态和基础 HP 变化：

| dHead 范围 | POST | HP 基础影响 |
|---|---|---:|
| `>= 26cm` | `SAFE` | 每分钟 +1 |
| `20..25cm` | `WARN` | 每分钟 -1 |
| `< 20cm` | `DANGER` | 每分钟 -3 |

LCD 会显示：

```text
TDIF xxxxCM
TORS GOOD/LEAN/SIDE/TWIST
HEAD xxxxCM
```

这些显示只在 `seated=1` 时出现。

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

`health_lcd_top.v` 实例化三份 `top_Ranging.v`：

```verilog
top_Ranging u_ultrasonic_front (...);
top_Ranging u_ultrasonic_left45 (...);
top_Ranging u_ultrasonic_right45 (...);
```

正前方 `dHead` 距离饱和到 10-bit 后给 LCD 和 HP 使用：

```verilog
assign posture_distance_cm =
    (ultrasonic_front_distance_cm > 16'd1023) ? 10'd1023 : ultrasonic_front_distance_cm[9:0];
```

左右肩方向距离饱和到 10-bit 后进入躯干分析模块：

```verilog
torso_posture_analyzer #(
    .CLK_HZ(CLK_HZ)
) u_torso (
    .clk(clk),
    .rst_n(rst_n),
    .seated(seated),
    .front_distance_cm(posture_distance_cm),
    .left45_distance_cm(shoulder_left45_distance_cm),
    .right45_distance_cm(shoulder_right45_distance_cm),
    .shoulder_diff_cm(shoulder_diff_cm),
    .torso_state(torso_state),
    .torso_hp_penalty(torso_hp_penalty)
);
```

## 上板连接建议

连接超声波模块时：

- FPGA `ultrasonic_front_trig` 接正前方模块 `Trig`。
- FPGA `ultrasonic_front_echo` 接正前方模块 `Echo`。
- FPGA `ultrasonic_left45_trig` 接左前 45 度模块 `Trig`。
- FPGA `ultrasonic_left45_echo` 接左前 45 度模块 `Echo`。
- FPGA `ultrasonic_right45_trig` 接右前 45 度模块 `Trig`。
- FPGA `ultrasonic_right45_echo` 接右前 45 度模块 `Echo`。
- FPGA GND 必须和超声波模块 GND 共地。
- 如果 Echo 是 5 V 电平，必须通过分压或电平转换接入 FPGA。

Vivado 工程中需要加入本目录所有 `.v` 文件，并在 XDC 中约束：

```tcl
set_property IOSTANDARD LVCMOS33 [get_ports ultrasonic_front_echo]
set_property IOSTANDARD LVCMOS33 [get_ports ultrasonic_front_trig]
set_property IOSTANDARD LVCMOS33 [get_ports ultrasonic_left45_echo]
set_property IOSTANDARD LVCMOS33 [get_ports ultrasonic_left45_trig]
set_property IOSTANDARD LVCMOS33 [get_ports ultrasonic_right45_echo]
set_property IOSTANDARD LVCMOS33 [get_ports ultrasonic_right45_trig]
```

具体 `PACKAGE_PIN` 按实际 EGO1 接线填写。


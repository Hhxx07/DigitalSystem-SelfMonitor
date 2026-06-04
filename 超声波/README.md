# 三路超声波测距子系统

本目录为健康坐姿系统提供三路距离：

```text
dHead：正前方，测量头部/上身离桌距离
dL：左前方传感器，测量左胸前/肩前斜距
dR：右前方传感器，测量右胸前/肩前斜距
```

## 硬件接口

每个超声波模块除电源外包含：

| 引脚 | 方向 | 说明 |
|---|---|---|
| `Trig` | FPGA 输出 | 高电平脉冲触发测距。 |
| `Echo` | FPGA 输入 | 高电平宽度表示声波往返时间。 |

若 Echo 输出为 5 V，必须先分压或电平转换到 FPGA I/O 可接受的电压。

## 文件关系

```text
top_Ranging.v
├── trig_generator.v  产生周期触发脉冲
├── signal_sync.v     两级同步和边沿检测
└── distance_calc.v   Echo 脉宽换算为厘米

torso_posture_analyzer.v
└── 使用 dL/dR 判断 GOOD/LEAN/SIDE/TWIST
```

## 单路顶层

```verilog
module top_Ranging #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer TRIG_START_DELAY_CYCLES = 0
)(
    input  wire clk,
    input  wire rst_n,
    input  wire ultrasonic_echo,
    output wire ultrasonic_trig,
    output wire [15:0] distance_cm
);
```

`distance_cm=0` 表示复位后尚未得到有效回波。LCD 顶层不会把零距离用于入座判断。

## 错峰触发

`trig_generator.v` 默认周期为 65 ms，脉冲宽度为 25 us。`START_DELAY_CYCLES` 用于改变同一周期内的发射时刻。

`health_lcd_top.v` 当前配置：

| 通道 | 触发延迟 |
|---|---:|
| 正前方 | 0 ms |
| 左 45 度 | 约 22 ms |
| 右 45 度 | 约 44 ms |

三路不再同时发射，可降低一个传感器收到另一个传感器回波的概率。

## 距离换算

`signal_sync.v` 先对异步 Echo 做两级同步，再产生上升沿和下降沿脉冲。

`distance_calc.v` 在 Echo 高电平期间计数。当前经验系数约为：

```text
100 MHz 下约 5600 个时钟周期 = 1 cm
```

该换算固定按 100 MHz 标定。若实际系统时钟不是 100 MHz，必须重新调整 `distance_calc.v`；仅修改 `top_Ranging.CLK_FREQ_HZ` 只会改变 Trig 周期，不会自动改变距离换算。

## 安装建议

左右传感器：

- 水平方向向桌子中线内收约 8 度。
- 垂直方向微上仰约 3 度。
- 正常坐正时，`dL/dR` 通常约 24 到 30 cm。

正前方头部距离传感器：

- 安装在桌子中线靠前位置，建议桌面以上约 40 cm。
- 相对桌前沿向后约 6 cm。
- 向下俯角约 25 到 35 度。
- 正常坐姿下 `dHead` 通常约 28 到 42 cm。

以上数值是初始安装参考，最终阈值应按实际桌面、座椅和使用者标定。

## 躯干判断

```text
TDIF = abs(dL - dR)
```

异常必须持续 `STABLE_MS` 才更新状态，默认 500 ms。

| 条件 | 状态 | HP 额外影响 |
|---|---|---:|
| `dL/dR` 均在 24..30cm 且 `TDIF < 5cm` | GOOD | 0 |
| 任一侧离开 24..30cm，未触发更严重条件 | LEAN | `-1/min` |
| 任一侧 `<19cm` | SIDE | `-2/min` |
| `TDIF >=5cm`，且没有单侧过近 | TWIST | `-3/min` |

判断优先级：

```text
SIDE > TWIST > LEAN > GOOD
```

正前方 `dHead` 不在 `torso_hp_penalty` 中重复扣分，而是由 `hp_engine.v` 独立处理：

| dHead | POST | HP 基础影响 |
|---|---|---:|
| `>=26cm` | SAFE | `+1/min` |
| `20..25cm` | WARN | `-1/min` |
| `<20cm` | DANGER | `-3/min` |

## LCD 显示

入座时显示：

```text
TDIF xxxxCM
TORS GOOD/LEAN/SIDE/TWIST
HEAD xxxxCM
```

离座时这些行留空。

## Vivado 注意事项

- 三路 Echo 都是异步输入。
- 三路 Echo 若为 5 V，必须电平转换。
- Trig 和 Echo 走线尽量分开。
- 三个超声波模块与 FPGA 必须共地。
- 当前距离换算按 100 MHz 设计。

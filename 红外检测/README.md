# PIR 红外检测子系统

本目录包含两种 PIR 处理方式。

## 文件组成

| 文件 | 用途 |
|---|---|
| `pir_human_detector.v` | 当前 `health_lcd_top` 使用的完整模块：预热、同步、稳定滤波和活动窗口。 |
| `pir_motion_hold_detector.v` | 简化的运动保持模块，可用于独立测试或其他包装顶层。当前推荐双板 LCD 顶层不再重复实例化它。 |
| `tb_pir_human_detector.v` | `pir_human_detector` 回归测试。 |

## pir_human_detector

接口：

```verilog
input  wire pir_in;
output wire pir_raw_sync;
output reg  pir_valid;
output reg  human_present;
output reg  ir_active;
```

处理流程：

1. `pir_in` 经过两级触发器同步到 `clk`。
2. 上电后等待 `WARMUP_SEC`，预热期间 `pir_valid=0`。
3. 输入电平必须稳定 `STABLE_MS` 才更新 `human_present`。
4. `human_present=1` 期间持续刷新活动窗口。
5. PIR 回到低电平后，如果 `INACTIVE_WINDOW_SEC` 内没有新活动，`ir_active` 清零。

PIR 本质上是运动传感器，无法可靠检测完全静止的人，因此系统使用活动保持窗口，而不是直接用 PIR 当前电平作为入座信号。

## 和主系统的关系

```text
pir_in -> pir_human_detector -> ir_active

seated = ir_active && ultrasonic_seated && pressure_ok
```

`ir_active=0` 会否决入座。

## 主要参数

| 参数 | 默认值 | 说明 |
|---|---:|---|
| `CLK_FREQ_HZ` | `100000000` | 系统时钟。 |
| `WARMUP_SEC` | `60` | 传感器上电预热时间。 |
| `STABLE_MS` | `100` | 输入稳定滤波时间。 |
| `INACTIVE_WINDOW_SEC` | `180` | 最后一次活动结束后的保持时间。 |
| `SIM_FAST` | `0` | 快速仿真开关。上板必须为 0。 |
| `INACTIVE_WINDOW_CYCLES_FAST` | `200` | 快速仿真时的窗口周期数。 |

`health_lcd_top.PIR_SIM_FAST` 会传给本模块的 `SIM_FAST`。

## 仿真

```powershell
cd 红外检测
iverilog -g2001 -Wall -o tb_pir_human_detector.vvp tb_pir_human_detector.v pir_human_detector.v
vvp tb_pir_human_detector.vvp
```

测试覆盖预热、稳定高低电平、短毛刺、持续高电平刷新窗口和低电平后的窗口超时。

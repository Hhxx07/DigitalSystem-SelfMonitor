# 数字系统健康坐姿项目总览

这是项目总文档的大纲版，用于说明各子系统位置和集成关系。更详细的模块说明见各子目录 README。

## 目录结构

```text
src/
├── lcd/        ST7735S LCD 显示、RTC、座位状态机、HP 引擎、系统顶层
├── 超声波/    三路超声波测距，提供正前头部离桌距离和左右 45 度斜距
├── 红外检测/  红外人体检测相关模块
└── 称重/      压力/称重检测相关模块
```

## 系统顶层

当前主顶层是：

```text
lcd/health_lcd_top.v
```

它负责集成：

- LCD 初始化和刷新显示
- RTC 日期时间
- 座位状态机 `IDLE/STUDY/SEDENTARY/OVER/REST/AWAY`
- HP 计算与报警
- 三路超声波测距、头部离桌判断与躯干状态判断
- 四角称重重心分布接口
- 压力和红外入座判断

## 主要硬件接口

系统外设接口大致包括：

- 100 MHz 系统时钟 `clk`
- 低有效复位 `rst_n`
- 压力检测输入 `pressure_ok`
- 红外检测输入 `pir_in`（PIR 原始信号，由内部模块处理为 ir_active 活动标志）
- 正前方头部距离超声波 `ultrasonic_front_echo/trig`
- 左前 45 度超声波 `ultrasonic_left45_echo/trig`
- 右前 45 度超声波 `ultrasonic_right45_echo/trig`
- 四角称重数值输入：左前、左后、右前、右后
- 重心分布输出：前后差值/等级、左右差值/等级
- LCD SPI 接口：`lcd_cs_n/lcd_rst_n/lcd_dc/lcd_scl/lcd_mosi/lcd_blk`

## 数据流大纲

```text
压力 + 红外（pir_in → pir_human_detector → ir_active） + 超声波距离
  -> seated = ir_active && ultrasonic_seated && pressure_ok
  -> seat_fsm 生成座位状态和学习/离座计时

三路超声波 Echo/Trig
  -> top_Ranging x3
  -> 正前 dHead + 左右 45 度 dL/dR 斜距
  -> posture_level + torso_posture_analyzer
  -> hp_engine 和 LCD 距离/躯干显示

四角称重
  -> weight_balance_analyzer
  -> 前后重心差值/等级 + 左右重心差值/等级

seat_fsm + distance_cm + torso_state
  -> hp_engine
  -> HP、姿势状态、躯干扣分、报警

RTC + seat_fsm + hp_engine + distance_cm + torso_state
  -> display_renderer
  -> st7735_spi
  -> LCD 屏幕
```

## 当前 LCD 显示内容

LCD 显示：

- 日期 `YYYY-MM-DD`
- 时间 `HH:MM:SS`
- 座位状态 `STAT ...`
- 姿势状态 `POST ...`
- 学习计时 `SIT mmmm:ss`
- 离座计时 `AWAY mmmm:ss`
- 当前计时 `NOW mmmm:ss`
- 左右 45 度斜距差 `TDIF xxxxCM`
- 躯干状态 `TORS GOOD/LEAN/SIDE/TWIST`
- 头部离桌距离 `HEAD xxxxCM`，仅入座时显示
- HP 数值和底部血条

## 状态与策略摘要

- `seated = ir_active && ultrasonic_seated && pressure_ok`（红外有否决权：ir_active=0 直接判无人）
- 入座后进入 `STUDY`
- 坐满 45 分钟进入久坐
- 坐满 60 分钟进入过度久坐
- 离座进入休息状态
- 离座超过 20 分钟进入长时间离开
- 离座超过 30 分钟进入 `IDLE`
- 进入 `IDLE` 后 HP 恢复为 100，下一次学习从满 HP 开始
- 正前 `dHead` 按 `>=26cm / 20..25cm / <20cm` 影响 `POST SAFE/WARN/DANGER`
- 左右 45 度 `dL/dR` 按 24..30cm 正常范围、5cm 差值和 19cm 单侧过近阈值判断 `GOOD/LEAN/SIDE/TWIST`
- 躯干微倾、侧弯、扭转会按等级额外扣 HP

## 子文档

- `lcd/README.md`：LCD 顶层、显示渲染、状态机、HP、仿真说明
- `超声波/README.md`：三路超声波硬件接口、测距流程、躯干状态判断
- `称重/README.md`：四角称重预留接口、前后/左右重心分布输出

## 仿真入口

主要回归 testbench：

```text
lcd/tb_health_lcd_top.v
```

在 `lcd/` 目录下运行 README 中的 `iverilog` 命令即可验证 LCD 顶层与超声波测距模块的集成。


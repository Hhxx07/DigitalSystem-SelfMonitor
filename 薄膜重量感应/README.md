# FSR402 薄膜压力单板调试方案

本目录是独立的单板调试方案：一块 EGO1 直接通过 XADC 读取四个 FSR402，并通过 ASCII UART 输出压力值。

它适合传感器接线、分压和标定调试。最终双板系统推荐使用 `../two_board_weight_link/` 中的二进制数据包方案。

## 文件关系

```text
fpga_fsr402_top.v
├── xadc_4ch_reader.v
├── uart_fsr402_streamer.v
│   └── uart_tx.v
└── LED 心跳
```

## 硬件接口

四路 XADC：

| 位置 | XADC 通道 |
|---|---|
| 左前 FL | VAUX0 |
| 右前 FR | VAUX2 |
| 左后 BL | VAUX3 |
| 右后 BR | VAUX8 |

EGO1 XADC 模拟输入范围约为 0 到 1.0 V。若 FSR402 调理电路输出可能达到 3.3 V，必须使用分压，不能直接接入 XADC。

## xadc_4ch_reader

- 使用 Xilinx 7 系列 `XADC` 原语连续扫描 VAUX0/2/3/8。
- 每路累计 16 个样本后取平均。
- 输出 12-bit 压力值。
- 当前代码对 XADC 码值取反，使“压力越大，输出数值越大”。

该模块依赖 Vivado 的 Xilinx 原语库。Icarus Verilog 无法完整模拟真实 XADC 行为。

## UART 输出

`uart_fsr402_streamer.v` 默认以 115200 baud、5 Hz 输出：

```text
FL=dddd FR=dddd BL=dddd BR=dddd\r\n
```

该 ASCII 方案便于串口终端观察，但不作为当前 LCD 板的数据链路。

## 顶层

```text
fpga_fsr402_top
```

功能：

- 上电保持约 10 ms 内部复位。
- 读取四路 XADC。
- 周期输出 ASCII 串口。
- LED 心跳显示逻辑运行状态。

## 与双板方案区别

| 单板调试方案 | 双板方案 |
|---|---|
| ASCII 文本，便于人工查看 | 固定长度二进制帧，便于 FPGA 接收 |
| 只上报四路压力值 | 同时发送入座、重心等级和方向 |
| 顶层 `fpga_fsr402_top` | 顶层 `weight_board_link_top` |

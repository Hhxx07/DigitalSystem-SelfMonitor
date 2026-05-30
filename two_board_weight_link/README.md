# Two EGO1 Board Weight Link

This folder contains the board-to-board Verilog link for the seat cushion pressure system.

## Roles

- Weighing board: reads four FSR402 sensors through XADC, filters values, decides whether someone is seated, analyzes front/back and left/right imbalance, then sends a UART packet.
- LCD/status board: receives the UART packet, checks the checksum, exposes `pressure_ok` and four 16-bit weight values for `lcd/health_lcd_top.v`.

## Physical Connection

Use normal digital IO on J5, not the XADC analog pins.

Recommended link:

| Weighing board | LCD/status board | Function |
|---|---|---|
| J5-25 / H14 / `link_uart_tx` | J5-25 / H14 / `link_uart_rx` | 115200 UART data |
| GND | GND | Common ground |

Do not connect the two boards' 3.3V rails together unless you intentionally design shared power.

## FSR402 XADC Wiring On Weighing Board

Each FSR402 AO must be divided from 0-3.3V to below 1.0V before entering XADC.

```text
FSR402 AO -- 24k --+-- ADxP
                   |
                  10k
                   |
                  GND

ADxN ------------- GND
```

Current channel mapping:

| Seat corner | XADC channel | EGO1 J5 pins | FPGA pins |
|---|---|---|---|
| FL left front | AD0 | J5-13 / J5-14 | D14 / C14 |
| FR right front | AD2 | J5-1 / J5-2 | B16 / B17 |
| BL left rear | AD3 | J5-5 / J5-6 | A13 / A14 |
| BR right rear | AD8 | J5-11 / J5-12 | B13 / B14 |

## Folder Layout

```text
weight_board/   weighing sensor board project files
lcd_board/      LCD/status receiving board project files
```

Each board folder is self-contained for its own Vivado project.

## Weighing Board Vivado Sources

Use files under `weight_board/` only.

Top module:

```text
weight_board_link_top
```

Add these files:

```text
weight_board/src/weight_board_link_top.v
weight_board/src/xadc_4ch_reader.v
weight_board/src/seat_weight_analyzer.v
weight_board/src/weight_packet_tx.v
weight_board/src/uart_tx.v
```

Constraint example:

```text
weight_board/weight_board_ego1.xdc
```

## First Link Test On LCD/Status Board

Use files under `lcd_board/` only.

Before integrating the LCD, first verify the board-to-board UART link with this top module:

```text
lcd_board_link_rx_top
```

Add these files:

```text
lcd_board/src/lcd_board_link_rx_top.v
lcd_board/src/lcd_weight_link_adapter.v
lcd_board/src/weight_packet_rx.v
lcd_board/src/uart_rx.v
```

Constraint example:

```text
lcd_board/lcd_board_rx_test_ego1.xdc
```

Expected LED behavior:

```text
D0: heartbeat, toggles once per second
D1: link_alive, high after valid packets arrive
D2: packet pulse, flashes when packets are received
D3: seat_present from packet flags
D4: checksum_error
```

## LCD/Status Board Vivado Sources

After the link test works, use the wrapper that directly instantiates `health_lcd_top`: 

```text
lcd_board_weight_lcd_top
```

Add these files from `lcd_board/`:

```text
lcd_board/src/lcd_board_weight_lcd_top.v
lcd_board/src/lcd_weight_link_adapter.v
lcd_board/src/weight_packet_rx.v
lcd_board/src/uart_rx.v
lcd_board/src/weight_balance_analyzer.v
```

Also add the existing LCD/status files from `../lcd` and its dependencies, including `health_lcd_top.v`.

Constraint example:

```text
lcd_board/lcd_board_link_example.xdc
```

Merge it with your real LCD, ultrasonic, reset, and IR pin constraints.

## UART Packet

Baud rate: 115200, 8N1.

The weighing board sends one binary frame at 10 Hz:

```text
A5 5A seq flags LF_H LF_L RF_H RF_L LR_H LR_L RR_H RR_L LR_STATE FB_STATE checksum 0A
```

Where:

```text
flags[0] = seat_present
flags[1] = lean_left
flags[2] = lean_right
flags[3] = lean_front
flags[4] = lean_back
LR_STATE = 0 balanced, 1 warning imbalance, 2 danger imbalance
FB_STATE = 0 balanced, 1 warning imbalance, 2 danger imbalance
checksum = XOR of bytes A5 through FB_STATE
```

The receiver only updates outputs when checksum and ending byte are valid.

## Default Thresholds

In `weight_board_link_top`:

```verilog
SEAT_ON_TH     = 800
SEAT_OFF_TH    = 300
WARN_PERCENT   = 15
DANGER_PERCENT = 30
```

These are starting values. Tune them after all four sensors are installed and the serial readings are stable.

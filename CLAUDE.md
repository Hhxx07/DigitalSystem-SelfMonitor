# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FPGA-based healthy sitting posture monitoring system targeting EGO1 (Xilinx Artix-7). Written in Verilog-2001. Drives an ST7735S 128x128 TFT LCD via 4-wire SPI. Integrates 3 ultrasonic sensors, PIR infrared detection, and FSR402 pressure sensing.

## Architecture

### Top-level
`lcd/health_lcd_top.v` is the system top. It integrates:
- `pir_human_detector.v` — PIR sensor processing with inactivity window (ir_active output)
- `rtc_clock.v` — software RTC with 1 Hz tick
- `seat_fsm.v` — seat state machine (IDLE/STUDY/SEDENTARY/OVER/REST/AWAY)
- `hp_engine.v` — HP calculation (head distance + torso penalty)
- `top_Ranging.v` ×3 — ultrasonic distance modules (front/left45/right45)
- `torso_posture_analyzer.v` — torso state from left/right 45° distances
- `weight_balance_analyzer.v` — 4-corner weight center-of-gravity analysis
- `st7735_init.v` — LCD init sequence
- `display_renderer.v` — real-time frame rendering (no frame buffer)
- `font_rom.v` — 8x8 ASCII glyph ROM
- `st7735_spi.v` — SPI byte transmitter

### Key Data Flow
```
pir_in → pir_human_detector → ir_active
ir_active + ultrasonic_seated (3x dist < threshold) + pressure_ok → seated → seat_fsm + hp_engine
ultrasonic Echo/Trig → top_Ranging ×3 → distances → torso_posture_analyzer → hp_engine
4-corner weight → weight_balance_analyzer → balance outputs
seat_fsm + RTC + distances + hp → display_renderer → st7735_spi → LCD
```

### State Machine (seat_fsm)
```
0=IDLE, 1=STUDY, 2=SEDENTARY (>45min), 3=OVER_SEDENTARY (>60min),
4=REST, 5=AWAY_LONG (>20min), IDLE (>30min away → resets HP to 100)
```

### HP Engine Rules
- `dHead >= 26cm`: +1/min, `20-25cm`: -1/min, `<20cm`: -3/min
- Torso penalty: LEAN -1, SIDE -2, TWIST -3 (from left/right 45° sensors)
- HP saturates at 0/100

### Subsystems
- `超声波/` — `trig_generator.v` + `signal_sync.v` + `distance_calc.v` (5600 cycles ≈ 1cm at 100MHz)
- `红外检测/` — `pir_human_detector.v` with warmup timer, stable debounce filter, and inactivity window counter → outputs `ir_active`
- `薄膜重量感应/` — `xadc_4ch_reader.v` + `uart_fsr402_streamer.v` + `uart_tx.v` (115200 baud, 5Hz report)

## Simulation with Iverilog

Run the main testbench:
```powershell
cd lcd
iverilog -g2001 -Wall -o tb_health_lcd_top.vvp tb_health_lcd_top.v health_lcd_top.v st7735_spi.v st7735_init.v display_renderer.v font_rom.v rtc_clock.v seat_fsm.v hp_engine.v ..\红外检测\pir_human_detector.v ..\超声波\top_Ranging.v ..\超声波\trig_generator.v ..\超声波\signal_sync.v ..\超声波\distance_calc.v ..\超声波\torso_posture_analyzer.v ..\称重\weight_balance_analyzer.v
vvp tb_health_lcd_top.vvp
```

PIR detector testbench:
```powershell
cd 红外检测
iverilog -g2001 -Wall -o tb_pir_human_detector.vvp tb_pir_human_detector.v pir_human_detector.v
vvp tb_pir_human_detector.vvp
```

Expected output: `ALL TESTS PASSED`

## Synthesis with Vivado

- Target: EGO1 (Artix-7), 100 MHz clock
- Set `lcd/health_lcd_top.v` as top module
- Add all `.v` files from `lcd/`, `超声波/`, `红外检测/`, `薄膜重量感应/`
- Use `lcd/ego1_st7735_example.xdc` — edit PACKAGE_PIN for actual board wiring
- `sim_fast` must be tied to 0 on board
- `CLK_HZ` parameter must match actual clock (100000000 for EGO1)

## Key Parameters

| Parameter | Default | Purpose |
|---|---|---|
| `CLK_HZ` | 100000000 | System clock frequency |
| `SPI_CLK_DIV` | 5 | ~10 MHz SPI at 100 MHz |
| `FRAME_HZ` | 2 | LCD refresh rate |
| `MADCTL_PARAM` | 8'h00 | ST7735 orientation |
| `LCD_X_OFFSET` | 16'd2 | CASET offset (fix left shift) |
| `LCD_Y_OFFSET` | 16'd1 | RASET offset (fix up shift) |
| `INIT_HP` | 100 | Starting health points |

## Hardware Interface

- Clock: 100 MHz, Reset: active-low (`rst_n`)
- `seated = ir_active && ultrasonic_seated && pressure_ok` (IR has veto: ir_active=0 → seated=0)
- `ir_active` = PIR trigger count within 3-min window (rising edges of debounced human_present)
- `ultrasonic_seated` = all 3 ultrasonic distances < ULTRASONIC_SEATED_THRESHOLD_CM (default 120cm)
- LCD: 4-wire SPI (CS_n, RST_n, DC, SCL, MOSI, BLK)
- Ultrasonic: standard Echo/Trig interface (watch for 5V Echo → level shift needed)
- FSR402: XADC VAUX pins (p0/n0, p2/n2, p3/n3, p8/n8) + UART TX (115200)
- IOSTANDARD: LVCMOS33 for all I/O

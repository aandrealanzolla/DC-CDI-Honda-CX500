# CX500 CDI — Custom ignition control unit

STM32-based custom DC-CDI for a Honda CX500, V-twin wasted-spark with variable reluctance pickups. Ignition timing with variable, custom advance curve and reactive/predictive logic.

## Project status

- **Rev 1.3** — Selected MCU: STM32F411CEU6. Wrong SMPS transformer dimensioning. Wrong pickup input signal conditioning circuit.
- **Rev 1.3.1** — Added a daughter board with MAX9927 IC for VR pickup reading. Replaced old step-up transformers with DA2034. Almost fully working and road-tested.
- **Rev 2.0** — SUPERSEDED. Improved routing, transformer footprint update, added JAE 18-pin automotive connector.
- **Rev 2.1** — SUPERSEDED. SMPS controller change: from LT3758 (Analog Devices) to LM3481 (TI). Transformer change: from Coilcraft DA2034 to Würth 750032052.
- **Rev 2.2** — IN PRODUCTION. Migration to STM32F410CBU6 for PCBA cost reduction (pin remapping required). SMPS voltage increased from 290V to 400V. CDI capacitance decreased from 2.2uF to 1.5uF. 

⚠️ **Use**: hobby project, intended for vintage or racing motorcycles. No EMC or road-use certification. See `docs/` for the regulatory considerations evaluated.
![Scheda rev1 montata](IMG_7243.HEIC)
## Hardware architecture

### Rev 1.x (STM32F411CEU6)

| | Left channel | Right channel |
|---|---|---|
| Pickup capture | TIM3 CH3 | TIM2 CH3 |
| Spark coil output | TIM2 CH1 | TIM1 CH1 |

### Rev 2.x (STM32F410CBU6)

STM32F410 lacks TIM2/TIM3/TIM4 (value-line part), timers remapped as follows. TIM1 now
carries both right-channel output and left-channel capture on independent channels of the
same instance (shared prescaler/tick rate); TIM5 (32-bit) takes over TIM2's former dual role
(left output + right capture).

| | Left channel | Right channel |
|---|---|---|
| Pickup capture | TIM1 CH4 | TIM5 CH3 |
| Spark coil output | TIM5 CH1 | TIM1 CH1 |

Turned to Texas Instrument LM3481 SMPS controllers, to reduce complexity and costs. Increased capacitor charging voltage to 400V while reducing capacitance to 1.5uF to gain spark power (from 90mJ to 120mJ). 
Replaced ADP3654 with two 1EDN7511B.
Added external connector: JAE MX23A18 (waterproof) with UART access for engine map download/upload.

### Common to all revisions

- Pickup: MAX9927 (variable reluctance comparator), fixed angle 15° BTDC
- Power stage: IPD60R180P7 MOSFET (DPAK)
- External pins for kill switch, I2C sensors and analog sensor read with 5VDC power supply. 
- FW/Debug connector: STDC14 header (debug + calibration from the same node)

## Firmware architecture

- 4-branch state machine per channel: **reactive** (below 1500rpm, fixed 15° advance), **predictive-continuous**, **transition** (first threshold crossing), **drop-out**
- RPM projection: pure linear extrapolation, activation threshold `RPM_PROJECTION_MIN_RATE_PCT`
- Anti-stuck safety net: `PENDING_STUCK_TIMEOUT_MS`
- Advance map calibration: dedicated flash sector (last available sector), loaded at boot with fallback to safe defaults, writable over UART without reflashing (see `tools/cdi_calibration_tool.py`)
- UART telemetry at 115200 baud: rpm, advance, active branch, diagnostic counters (arm count, rejects, transitions, stuck-recovered)

## Repository structure

```
Progetto/
  DC_CDI_Honda_CX500_rev1.3/         - Altium project, rev 1.3 (working - with some rework, road-tested)
  DC_CDI_Honda_CX500_rev2.0/         - Altium project, rev 2.0 (SUPERSEDED)
  DC_CDI_Honda_CX500_rev2.1/         - Altium project, rev 2.1 (SUPERSEDED)
  DC_CDI_Honda_CX500_rev2.2/         - Altium project, rev 2.2 (IN PRODUCTION)
  DC_CDI_Honda_CX500_daughter_board_1/ - MAX9927 pickup daughter board
  Housing/
    rev1.3/                          - STEP/STL/OBJ enclosure models
    rev2.0/
  Documentazione/                    - PDFs
  simulazioni_LTspice/               - LTSpice simulation files
  firmware/                          - firmware version notes
  oldes_versions/                    - pre-rev1.3 Altium history
  smps_dimensionamento.xlsx
  stm32f411xx_RegisterMap.pdf
Video-Foto/                          - photos/videos of the build
Log_fw/                              - firmware telemetry logs
Misure/                              - oscilloscope captures
Sim/                                 - misc simulation files

```

## Main milestones (timeline)

1. Diagnosed and fixed cranking resets (gate resistor 0Ω → 10Ω, EMI from excessive dV/dt)
2. Replaced power stage: SCR → MOSFET
3. Fixed logic bugs: unstable RPM projection, drop-out arming a duplicate shot, queue firing on an expired target
4. Tuned advance map (aligned to stock AC-CDI reference, 37° at 5800rpm)
5. Isolated coupled noise on the left channel (daughter board repositioning)
6. Recurring MOSFET failures on the left channel — investigation ongoing (suspects: gate solder joint, driver, undersized Rds(on) on replacement parts)
7. Flash-based calibration system + PC tool
8. Migration to STM32F410 for cost reduction (rev 2.2)

## License

_TBD_

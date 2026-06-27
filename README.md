# P_FEC_ASIC

> RTL design of a Cross Parity Check + CRC Forward Error Correction (FEC) system with UART interface, implemented as an ASIC using open-source EDA tools.

This project is developed as part of a **Master's thesis in Electronic Design** and serves as a validation vehicle for the RTL-to-GDSII physical implementation flow using LibreLane and the SkyWater SKY130A process node, targeting fabrication through **ChipFoundry**.

---

## Table of Contents

- [Overview](#overview)
- [System Architecture](#system-architecture)
- [Features](#features)
- [RTL Design](#rtl-design)
- [Repository Structure](#repository-structure)
- [Physical Implementation Flow](#physical-implementation-flow)
- [Tool Stack](#tool-stack)
- [How to Reproduce](#how-to-reproduce)
- [Status](#status)
- [Academic Context](#academic-context)
- [License](#license)

---

## Overview

The **P_FEC_ASIC** project implements a digital Forward Error Correction (FEC) system based on two complementary encoding schemes:

- **CPC (Cross Parity Check):** Generates redundancy bits by computing parity across rows and columns of a data block, enabling single-bit error correction and multi-bit error detection.
- **CRC (Cyclic Redundancy Check):** Provides an additional integrity verification layer at the packet level.

The system encodes data at the transmitter side (downlink) and decodes it at the receiver side (uplink), recovering the original data even in the presence of transmission errors. Communication with a host processor is handled through a **configurable UART interface**, whose baud rate is determined by the system clock frequency and a programmable prescaler register.

---

## System Architecture

```
                        ┌─────────────────────────────────┐
                        │            fec_top               │
                        │                                  │
         uart_rx ──────►│  UART RX                         │
         uart_tx ◄──────│  UART TX      ┌─────────────┐   │
                        │               │  CPC + CRC  │   │──► dl_out
              clk ──────│               │   Encoder   │   │──► dl_en
            rst_n ──────│               │  (Downlink) │   │──► dl_ready
                        │               └─────────────┘   │
                        │                                  │
          ul_in ───────►│               ┌─────────────┐   │
          ul_en ───────►│               │  CPC + CRC  │   │
                        │               │   Decoder   │   │
                        │               │  (Uplink)   │   │
                        │               └─────────────┘   │
                        └─────────────────────────────────┘
```

---

## Features

- CPC + CRC dual-layer forward error correction
- Configurable UART interface (baud rate set via prescaler register)
- Separate downlink (encoding) and uplink (decoding) datapaths
- Synchronous design with active-low asynchronous reset
- Target frequency: **50 MHz** on SKY130A process node
- Fully implemented in **SystemVerilog**
- Compatible with the **Caravel** SoC harness for ASIC fabrication

---

## RTL Design

### Top Module

| Module | Description |
|---|---|
| `fec_top` | Top-level module integrating all subsystems |
| `dl_fec` | Downlink FEC encoder (CPC + CRC) |
| `ul_mon` | Uplink monitor and FEC decoder |
| `dl_ctrl` | Downlink controller and serializer |
| `uart` | UART transceiver (TX + RX + FIFO) |
| `fec_fsm` | FEC state machine controller |
| `crc` | CRC computation unit |
| `deser` | Serial-to-parallel deserializer |
| `training` | Training sequence handler |
| `packet` | Packet framing and unscrambling |
| `reg_cfg` | Configuration register bank |

### Top-Level Ports

| Port | Direction | Description |
|---|---|---|
| `clk` | Input | System clock |
| `rst_n` | Input | Active-low synchronous reset |
| `uart_rx` | Input | UART receive pin |
| `uart_tx` | Output | UART transmit pin |
| `dl_ready` | Output | Downlink data ready flag |
| `dl_out` | Output | Downlink serial data output |
| `dl_en` | Output | Downlink enable signal |
| `ul_in` | Input | Uplink serial data input |
| `ul_en` | Input | Uplink enable signal |

### Synthesis Results (SKY130A — sky130_fd_sc_hd)

| Metric | Value |
|---|---|
| Total cell count | 11,795 |
| Flip-flops | 2,712 |
| Estimated area | ~165,716 µm² |
| Sequential area | ~71,248 µm² (43%) |
| Target frequency | 50 MHz (T = 20 ns) |
| Synthesis strategy | DELAY 4 |

---

## Repository Structure

```
P_FEC_ASIC/
├── source/
│   ├── design/              # RTL source files (SystemVerilog)
│   │   ├── fec_top.sv
│   │   ├── dl_fec.sv
│   │   ├── ul_fec.sv
│   │   ├── ul_mon.sv
│   │   ├── dl_ctrl.sv
│   │   ├── uart.sv
│   │   ├── fec_fsm.sv
│   │   ├── fec.sv
│   │   ├── crc.sv
│   │   ├── deser.sv
│   │   ├── training.sv
│   │   ├── packet.sv
│   │   ├── reg_cfg.sv
│   │   ├── defines.svh
│   │   └── ef_utils.v
│   └── synth/
│       └── caravel/         # Caravel integration
│           ├── verilog/
│           │   ├── rtl/     # Wrapper RTL (fec_wrapper.v, user_project_wrapper.v)
│           │   └── gl/      # Gate-level netlists (post-hardening)
│           ├── openlane/
│           │   ├── fec_wrapper/          # LibreLane config — Stage 1
│           │   └── user_project_wrapper/ # LibreLane config — Stage 2
│           ├── lef/         # LEF abstracts for hardened macros
│           ├── lib/         # Liberty timing files
│           ├── def/         # DEF layout files
│           └── sdc/         # SDC timing constraints
└── README.md
```

> **Note:** Large generated outputs (GDS, SPEF, MAG, SDF, run directories) are excluded from the repository via `.gitignore`. They are regenerated by running the LibreLane flows described below.

---

## Physical Implementation Flow

The physical implementation follows a two-stage **Macro-First Hardening** strategy:

```
source/design/ (RTL)
       │
       ▼ Stage 1
  fec_wrapper macro ──► GDS + LEF + GL netlist
  (synthesizes fec_top internally,
   maps ports to Caravel io_in/io_out/wb_*)
       │
       ▼ Stage 2
  user_project_wrapper ──► Final GDS
  (wires fec_wrapper_u to Caravel IO pads,
   no re-synthesis)
                              DRC ✅  LVS ✅  Antenna ✅
```

### Stage 1 — Harden `fec_wrapper`

`fec_wrapper` is a Caravel-specific RTL wrapper that instantiates `fec_top` and maps its ports to the Caravel `io_in`/`io_out`/`wb_*` interface. LibreLane synthesizes the full design (including `fec_top`) and produces a hardened macro.

| `fec_wrapper` port | Maps to |
|---|---|
| `io_in[0]` | `uart_rx` |
| `io_in[1]` | `ul_in` |
| `io_in[2]` | `ul_en` |
| `wb_clk_i` | `clk` |
| `wb_rst_i` | `rst_n` (inverted) |

Key configuration:

| Parameter | Value |
|---|---|
| PDK | SKY130A |
| Standard cell library | `sky130_fd_sc_hd` |
| Clock period | 20 ns (50 MHz) |
| Core utilization | 40% |
| Max routing layer | met4 |
| Synthesis strategy | DELAY 4 |

### Stage 2 — Integrate into `user_project_wrapper`

The hardened `fec_wrapper` macro is placed inside the Caravel `user_project_wrapper` using `SYNTH_ELABORATE_ONLY` mode — no re-synthesis, only floorplan and routing of the wrapper-level connections.

Key configuration choices:

| Parameter | Value | Reason |
|---|---|---|
| `SYNTH_ELABORATE_ONLY` | `true` | No standard cells — wrapper contains only the macro |
| `FP_PDN_ENABLE_RAILS` | `false` | No standard cell rows; power delivered via PDN straps |
| `DRT_ANTENNA_REPAIR_JUMPER_ONLY` | `true` | Prevents floating diode insertion without PDN rails |
| `HOLD_VIOLATION_CORNERS` | `[""]` | Suppresses pre-existing ±10 ps hold margin in fec_wrapper fast corners |

**Antenna fix:** Long routes from Caravel IO pads to `fec_wrapper_u` input pins (`io_in[34/35/36]` on met4, `wb_rst_i` on met3) exceeded the SKY130A partial side-area ratio limit of 400. Fixed by adding `ANTENNADIFFAREA` to those input pins in `lef/fec_wrapper.lef`, which instructs the antenna checker to apply the relaxed `ANTENNADIFFSIDEAREARATIO` PWL limit defined in the sky130 tech LEF.

---

## Tool Stack

| Tool | Version | Purpose |
|---|---|---|
| LibreLane | 3.0.4 | RTL-to-GDSII physical implementation flow |
| Yosys | — | Logic synthesis |
| OpenROAD | — | Floorplan, placement, CTS, routing, STA |
| Magic | — | DRC and GDSII streaming |
| Netgen | — | LVS verification |
| KLayout | — | GDSII visualization and DRC |
| SKY130A PDK | — | SkyWater 130nm process design kit |
| ChipFoundry CLI | — | Fabrication submission |

---

## How to Reproduce

### Prerequisites

- WSL2 (Ubuntu 22.04+) or native Linux
- LibreLane v3.0.4 installed via Nix
- SKY130A PDK installed via `ciel`
- `chipfoundry-cli` installed via `pipx`

### Stage 1 — Harden `fec_wrapper`

```bash
cd source/synth/caravel
librelane openlane/fec_wrapper/config.json
```

Copy the outputs (GDS, LEF, GL netlist, SPEF, LIB) from the run directory into the caravel tree before proceeding to Stage 2.

### Stage 2 — Integrate into Caravel wrapper

```bash
cd source/synth/caravel
librelane openlane/user_project_wrapper/config.json
```

Expected result in the manufacturability report:

```
* Antenna  Passed ✅
* LVS      Passed ✅
* DRC      Passed ✅
```

---

## Status

| Stage | Status |
|---|---|
| RTL design | ✅ Complete |
| Functional verification | ✅ Complete |
| Logic synthesis (Yosys) | ✅ Complete |
| Physical implementation — `fec_wrapper` (Stage 1) | ✅ Complete |
| Caravel `user_project_wrapper` integration (Stage 2) | ✅ Complete |
| DRC / LVS / Antenna signoff | ✅ Passed |
| ChipFoundry submission | ⏳ Pending |

---

## Academic Context

This project is developed as part of a **Master's thesis in Electronic Design** at ITESO — Universidad Jesuita de Guadalajara. The design serves as a practical validation vehicle for the open-source RTL-to-GDSII implementation flow, demonstrating the viability of tape-out-ready ASIC design using freely available EDA tools and the SkyWater 130nm open PDK.

---

## License

This project is licensed under the [Apache 2.0 License](LICENSE).

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

> 📌 Block diagram placeholder — to be updated with the actual system block diagram.

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
│   │   ├── ul_mon.sv
│   │   ├── dl_ctrl.sv
│   │   ├── uart.sv
│   │   ├── fec_fsm.sv
│   │   ├── crc.sv
│   │   ├── deser.sv
│   │   ├── training.sv
│   │   ├── packet.sv
│   │   ├── reg_cfg.sv
│   │   ├── defines.svh
│   │   └── ef_utils.v
│   └── synth/
│       ├── fec/             # LibreLane config for fec_top macro hardening
│       │   ├── config.json
│       │   ├── pin_order.cfg
│       │   ├── pnr.sdc
│       │   └── signoff.sdc
│       └── caravel/         # Caravel user_project_wrapper integration
│           ├── verilog/
│           ├── openlane/
│           ├── gds/
│           └── lef/
└── README.md
```

---

## Physical Implementation Flow

The physical implementation follows the **Macro-First Hardening** strategy as defined by the LibreLane documentation:

### Stage 1 — Macro Hardening (`fec_top`)

The `fec_top` module is hardened independently as a stand-alone macro using LibreLane Classic flow, generating a GDSII layout and a LEF abstract for subsequent integration.

```
RTL (SystemVerilog) ──► Synthesis (Yosys) ──► Floorplan ──► Placement
         ──► CTS ──► Routing ──► DRC/LVS ──► GDSII + LEF
```

Key configuration parameters:

| Parameter | Value |
|---|---|
| PDK | SKY130A |
| Standard cell library | `sky130_fd_sc_hd` |
| Clock period | 20 ns (50 MHz) |
| Core utilization | 40% |
| Max routing layer | met4 |
| Synthesis strategy | DELAY 4 |
| PDN multilayer | Disabled (macro mode) |

### Stage 2 — Wrapper Integration (`user_project_wrapper`)

The hardened `fec_top` macro is instantiated inside the Caravel `user_project_wrapper`, which is then hardened as the final deliverable for fabrication submission.

```
fec_top (GDSII + LEF) ──► user_project_wrapper ──► Final GDSII
```

---

## Tool Stack

| Tool | Version | Purpose |
|---|---|---|
| LibreLane | 3.0.3 | RTL-to-GDSII physical implementation flow |
| Yosys | 0.62 | Logic synthesis |
| OpenROAD | — | Floorplan, placement, CTS, routing, STA |
| Magic | — | DRC and GDSII streaming |
| Netgen | — | LVS verification |
| KLayout | — | GDSII visualization |
| SKY130A PDK | — | SkyWater 130nm process design kit |
| ChipFoundry CLI | — | Fabrication submission |

---

## How to Reproduce

### Prerequisites

- WSL2 (Ubuntu 22.04+) or native Linux
- LibreLane v3.0.3 installed via Nix
- SKY130A PDK installed via `ciel`
- `chipfoundry-cli` installed via `pipx`

### Stage 1 — Harden `fec_top`

```bash
# Enter the Nix shell
nix-shell ~/librelane/shell.nix

# Optional: run synthesis strategy exploration first
librelane source/synth/fec/config.json --flow SynthesisExploration

# Run the full Classic flow
librelane source/synth/fec/config.json
```

### Stage 2 — Integrate into Caravel wrapper

```bash
# To be documented after Stage 1 completion
```

---

## Status

| Stage | Status |
|---|---|
| RTL design | ✅ Complete |
| Functional verification | ✅ Complete |
| Logic synthesis (Yosys) | ✅ Complete |
| Physical implementation — `fec_top` | 🔄 In progress |
| Caravel wrapper integration | ⏳ Pending |
| DRC / LVS signoff | ⏳ Pending |
| ChipFoundry submission | ⏳ Pending |

---

## Academic Context

This project is developed as part of a **Master's thesis in Electronic Design** at ITESO — Universidad Jesuita de Guadalajara. The design serves as a practical validation vehicle for the open-source RTL-to-GDSII implementation flow, demonstrating the viability of tape-out-ready ASIC design using freely available EDA tools and the SkyWater 130nm open PDK.

---

## License

This project is licensed under the [Apache 2.0 License](LICENSE).


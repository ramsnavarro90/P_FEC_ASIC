# P_FEC_ASIC Copilot Instructions

## Project Overview
**P_FEC_ASIC** is an ASIC RTL design implementing a CPC+CRC Forward Error Correction (FEC) engine with UART communication interface. The design uses open-source EDA tools and targets silicon manufacturing.

**Top-level module:** `fec_top.sv` (457 lines)
**Package definitions:** `defines.svh` — contains all SystemVerilog parameters, enums, and `fec_pkg` typedef definitions. **Always read this first** when understanding data structures.

## Architecture

### Hierarchical Structure
```
fec_top (ASIC top module)
├── uart (UART TX/RX + arbiter)
├── dl_fec_fsm (Downlink FEC FSM — command processor)
├── dl_fec (Downlink FEC pipeline)
│   ├── fec (dual CRC+encoder engines: CRC0/ENC0 for 64-bit, CRC1/ENC1 for 16-bit)
│   └── packet_scramble (error injection + frame formatting)
├── dl_ctrl (serializer for parallel-to-serial conversion)
├── ul_fec (Uplink FEC pipeline)
├── ul_mon (uplink monitor)
└── reg_cfg (APB register interface)
```

### Critical Data Flows

**Downlink (UART → FEC → Serial output):**
1. UART RX receives bytes → `dl_fec_fsm` parses commands (register read/write or message TX)
2. Message data → CRC0 (56-bit data + CRC8) OR CRC1 (12-bit data + CRC4)
3. Encoder computes row/column parity (2×2 Hamming code)
4. `packet_scramble` formats frame with error injection capability
5. `dl_ctrl` serializes to single output (`dl_out`) with preamble (4×80-bit training sequence)

**Command Protocol** (defined in `defines.svh` `command_t` enum):
- `CMD_REG_READ/WRITE` (0x0, 0x2): APB register access via `reg_cfg`
- `CMD_TX_MSG` (0x4): FEC-protected message transmission
- `RSP_*` (0x1, 0x3, 0x5): Responses from ASIC
- `RSP_CMD_ERR` (0xF): Error indication

**APB Register Map** (see `reg_cfg.sv`):
- `0x00`: `DL_SER_CLK_DIV` — serializer clock divider (default 25ns period = 40MHz)
- `0x04-0x0C`: Error injection masks/enable (test/debug)
- `0x20-0x28`: UART parameters (baud rate divisor, control, config)

## Key Patterns & Conventions

### Package-First Design
All parameters are in `fec_pkg` (inside `defines.svh`). **Before modifying bit widths, data paths, or FIFO depths, update defines.svh parameters first.** Example:
- `CRC0_DATA_WIDTH = 56` (64-bit frame with 8-bit CRC)
- `ENC0_DATA_WIDTH = 8`, `ENC0_DATA_DEPTH = 8` (8×8 matrix for parity)
- `UART_SERIAL_CLK_DIV = 4` (clock divider for output serialization)

### Localparam Bit Field Layout
Downlink and uplink FIFOs use packed bit fields with localparam offsets:
```systemverilog
localparam int COL_START  = 0;
localparam int ROW_START  = COL0_END + 1;
localparam int CRC_START  = ROW0_END + 1;
localparam int DATA_START = CRC0_END + 1;
localparam int SAMP_BIT   = UL_FIFO_WIDTH - 1;
```
When accessing fields in FSMs or data paths, use these offsets—do not hardcode bit ranges.

### Parametrized FEC Engine (fec.sv)
Two identical CRC+encoder pairs with different widths:
- **FEC0:** 56-bit data, 8-bit CRC, 8×8 matrix (64-bit total)
- **FEC1:** 12-bit data, 4-bit CRC, 4×4 matrix (16-bit total)

Both expose: `data_in [WIDTH-1:0][DEPTH-1:0]`, `row_parity`, `col_parity`, `start`, `done`. FSM selects engine via `dl_ctrl_enc_used[1:0]`.

### SystemVerilog Conventions
- **Active-low reset:** `rst_n` everywhere
- **Clock-sensitive macros:** Use `@(posedge clk)` for simulation; defined in `tb_macros.svh`
- **Enum state machines:** State variables are `logic [N:0] state, next_state` with typedef'd enum (see `dl_fec_fsm.sv`, 1033 lines)
- **Unused includes:** Some `\`include` statements are commented (vestigial) — see `fec_top.sv` lines 6-8

## Build & Simulation

### Questa/ModelSim Compilation
**File list:** `source/questa/files.f` (declares compile order)
**Compile script:** `source/questa/compile.do`
```bash
cd source/questa
vsim -do compile.do  # Compiles and elaborates
vsim -do fec_top_tb.do  # Runs testbench
```
**Testbench:** `fec_top_tb.sv` (top-level test harness) + `testbench.sv` (stimulus logic)

### OpenLane2 Flow
**Config:** `openlane2/config.json` specifies:
- `DESIGN_NAME: fec_top`
- `CLOCK_PERIOD: 25` (ns) — 40MHz operation
- `VERILOG_FILES` list in compile order
- Pin configuration: `pin_order.cfg`

**Latest run:** `openlane2/runs/RUN_2026-01-28_19-22-18/`
- `01-verilator-lint/` — linting checks
- `02-checker-linttimingconstructs/` — timing validation
- `03-checker-linterrors/` — error detection

No synthesis/placement output exists yet; flow halted at lint stage.

## Testing Conventions

**Testbench macros** (`tb_macros.svh`):
- `\`TB_CLK(signal, period)` — generates clock
- `\`TB_SRSTN(signal, clk, duration)` — active-low reset pulse
- `\`WAIT_CLK(clk, cycles)` — delay by N clock cycles
- `\`TB_FINISH(time)` — end simulation
- `\`TB_DUMP(file, scope, depth)` — VCD waveform dump

Individual modules have focused testbenches:
- `crc_tb.sv`, `encoder_tb.sv`, `fec_tb.sv` (unit tests)
- `fec_top_tb.sv` (integration test)
- `uart_tb.sv`, `serializer_tb.sv` (I/O validation)

## Common Modifications

### Adding a Register
1. Update `reg_addr_t` enum in `defines.svh`
2. Add parameter + output logic to `reg_cfg.sv` port list
3. Add read/write case in `reg_cfg.sv` always_comb/always_ff blocks
4. Update `dl_fec_fsm.sv` to handle new command or address
5. Verify in testbench (`fec_top_tb.sv`)

### Changing FEC Frame Size
1. Update `CRC0_DATA_WIDTH`, `ENC0_DATA_WIDTH`, `ENC0_DATA_DEPTH` in `defines.svh`
2. Recalculate `ENC0_SERIAL_DATA_WIDTH` (parity bits + data + CRC)
3. Recompute localparam offsets (`COL_START`, `ROW_START`, etc.)
4. Update `packet_scramble.sv` bit assignments and `dl_ctrl.sv` serializer width
5. Update UART frame format in `dl_fec_fsm.sv`

### Adding Error Injection
Framework exists in `packet_scramble.sv`. Register map at `0x04-0x0C`:
- `DL_ERR_INJ_MASK_0` (bits [31:0])
- `DL_ERR_INJ_MASK_1` (bits [63:32])
- `DL_ERR_INJ_ENABLE` (single bit)

Modify FSM command handler to set these registers and verify with unit testbenches.

## Debug Tips

- **Linting failures:** Check `openlane2/runs/*/01-verilator-lint/COMMANDS` for issues
- **Simulation hangs:** Verify `\`TB_FINISH` in testbench; check UART FSM timeouts (`uart_error_t` enum)
- **Timing issues:** `CLOCK_PERIOD = 25ns` is tight; review `openlane2/runs/*/02-checker-linttimingconstructs/`
- **UART byte order:** MSB-first serialization in `dl_ctrl.sv`; verify parity packing in `packet_scramble.sv`

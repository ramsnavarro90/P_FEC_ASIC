# ============================================================
# signoff.sdc — Signoff timing constraints for fec_top
# Technology: SKY130A  |  Frequency: 50 MHz (T = 20 ns)
# Corner: max_ss_100C_1v60 (worst-case setup)
# Reflects actual design constraints after parasitic extraction.
# ============================================================

# --- Primary clock ---
create_clock -name clk -period 20.0 [get_ports clk]

# --- Clock uncertainty and transition ---
set_clock_uncertainty 0.25 [get_clocks clk]
set_clock_transition  0.15 [get_clocks clk]

# --- Synchronous input ports ---
# Nominal: 20% of clock period = 4 ns
set_input_delay -max 4.0 -clock clk [get_ports rst_n]
set_input_delay -min 1.0 -clock clk [get_ports rst_n]

# --- Asynchronous input ports ---
# uart_rx, ul_in, ul_en come from external devices with no
# internal synchronizer — declared as false paths for STA
set_false_path -from [get_ports {uart_rx ul_in ul_en}]

# --- Output ports ---
# Nominal: 20% of clock period = 4 ns
set_output_delay -max 4.0 -clock clk [get_ports {uart_tx dl_ready dl_out dl_en}]
set_output_delay -min 1.0 -clock clk [get_ports {uart_tx dl_ready dl_out dl_en}]

# --- Driving cell for synchronous input ports ---
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 -pin Y [get_ports rst_n]

# --- Output load ---
set_load 0.0334 [get_ports {uart_tx dl_ready dl_out dl_en}]
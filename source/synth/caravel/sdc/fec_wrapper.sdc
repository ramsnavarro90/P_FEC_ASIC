###############################################################################
# Created by write_sdc
###############################################################################
current_design fec_wrapper
###############################################################################
# Timing Constraints
###############################################################################
create_clock -name clk -period 20.0000 [get_ports {wb_clk_i}]
set_clock_uncertainty 0.1200 clk
set_propagated_clock [get_clocks {clk}]
set_clock_latency -source -min 4.4000 [get_clocks {clk}]
set_clock_latency -source -max 5.7000 [get_clocks {clk}]
set_input_delay 10.0000 -clock [get_clocks {clk}] -add_delay [get_ports {wb_rst_i}]
set_output_delay 1.0000 -clock [get_clocks {clk}] -min -add_delay [get_ports {io_out[0]}]
set_output_delay 4.0000 -clock [get_clocks {clk}] -max -add_delay [get_ports {io_out[0]}]
set_output_delay 1.0000 -clock [get_clocks {clk}] -min -add_delay [get_ports {io_out[1]}]
set_output_delay 4.0000 -clock [get_clocks {clk}] -max -add_delay [get_ports {io_out[1]}]
set_output_delay 1.0000 -clock [get_clocks {clk}] -min -add_delay [get_ports {io_out[2]}]
set_output_delay 4.0000 -clock [get_clocks {clk}] -max -add_delay [get_ports {io_out[2]}]
set_output_delay 1.0000 -clock [get_clocks {clk}] -min -add_delay [get_ports {io_out[3]}]
set_output_delay 4.0000 -clock [get_clocks {clk}] -max -add_delay [get_ports {io_out[3]}]
set_false_path\
    -from [list [get_ports {io_in[0]}]\
           [get_ports {io_in[1]}]\
           [get_ports {io_in[2]}]]
###############################################################################
# Environment
###############################################################################
set_load -pin_load 0.1900 [get_ports {io_oeb[3]}]
set_load -pin_load 0.1900 [get_ports {io_oeb[2]}]
set_load -pin_load 0.1900 [get_ports {io_oeb[1]}]
set_load -pin_load 0.1900 [get_ports {io_oeb[0]}]
set_load -pin_load 0.1900 [get_ports {io_out[3]}]
set_load -pin_load 0.1900 [get_ports {io_out[2]}]
set_load -pin_load 0.1900 [get_ports {io_out[1]}]
set_load -pin_load 0.1900 [get_ports {io_out[0]}]
set_input_transition 0.6100 [get_ports {wb_clk_i}]
set_timing_derate -early 0.9300
set_timing_derate -late 1.0700
###############################################################################
# Design Rules
###############################################################################
set_max_transition 0.7500 [current_design]
set_max_fanout 16.0000 [current_design]

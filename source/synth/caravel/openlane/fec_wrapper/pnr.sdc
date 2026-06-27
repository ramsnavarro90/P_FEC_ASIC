#------------------------------------------#
# Design Constraints
#------------------------------------------#
# Clock network
set clk_input wb_clk_i
create_clock [get_ports $clk_input] -name clk -period 20
puts "\[INFO\]: Creating clock {clk} for port $clk_input with period: 20"

# Clock non-idealities
set_propagated_clock [get_clocks {clk}]
set_clock_uncertainty 0.12 [get_clocks {clk}]
puts "\[INFO\]: Setting clock uncertainty to: 0.12"

# Maximum transition time for the design nets
set_max_transition 0.75 [current_design]
puts "\[INFO\]: Setting maximum transition to: 0.75"

# Maximum fanout
set_max_fanout 16 [current_design]
puts "\[INFO\]: Setting maximum fanout to: 16"

# Timing paths delays derate (aggressive for PnR)
set_timing_derate -early [expr {1-0.07}]
set_timing_derate -late  [expr {1+0.07}]
puts "\[INFO\]: Setting timing derate to: 7%"

#------------------------------------------#
# Retrieved Constraints (from Caravel boundary)
#------------------------------------------#
# Clock source latency
set usr_clk_max_latency 4.57
set usr_clk_min_latency 4.11
set clk_max_latency 5.70
set clk_min_latency 4.40
set_clock_latency -source -max $clk_max_latency [get_clocks {clk}]
set_clock_latency -source -min $clk_min_latency [get_clocks {clk}]
puts "\[INFO\]: Setting clock latency range: $clk_min_latency : $clk_max_latency"

# Clock input transition
set_input_transition 0.61 [get_ports $clk_input]

# Reset input delay
set_input_delay [expr {20 * 0.5}] -clock [get_clocks {clk}] [get_ports {wb_rst_i}]

# Asynchronous IO inputs — no internal synchronizer
set_false_path -from [get_ports {io_in[*]}]

# Output delays
set_output_delay -max 4.00 -clock [get_clocks {clk}] [get_ports {io_out[*]}]
set_output_delay -min 1.00 -clock [get_clocks {clk}] [get_ports {io_out[*]}]

# Tie-off outputs — false path (combinational constants)
#set_false_path -to [get_ports {wbs_ack_o wbs_dat_o[*] la_data_out[*] user_irq[*]}]

# Output loads
set_load 0.19 [all_outputs]
quit -sim
vsim -voptargs=+acc work.fec_top_tb +LOOPBACK +CLK_DIV=256 +TEST=test_fec_tx_set_clk_div +PAYLOAD=255 +uart_mon
#vsim -voptargs=+acc work.fec_top_tb +TEST=test_registers
#vsim -voptargs=+acc work.fec_top_tb +LOOPBACK +CLK_DIV=256 +TEST=test_fec_tx_err_inj_mask_2 +PAYLOAD=255 +uart_mon
dataset alias sim vsim
do fec_top_tb.wave
run 20 ms
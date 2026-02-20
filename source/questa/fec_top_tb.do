quit -sim
vsim -voptargs=+acc work.fec_top_tb +LOOPBACK +CLK_DIV=4 +TEST=test_fec_tx_set_clk_div +PAYLOAD=22
dataset alias sim vsim
do fec_top_tb.wave
run 100 ms
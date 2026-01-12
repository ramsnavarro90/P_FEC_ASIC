quit -sim
vsim -voptargs=+acc work.fec_top_tb +LOOPBACK +TEST=test_fec_tx_set_payload +PAYLOAD=9
do fec_top_tb.wave
run 100 ms
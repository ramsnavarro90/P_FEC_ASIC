if [file exists work] {vdel -all}
vlib work
vlog -f files.f -timescale "1 ns / 1 ps" +define+simulation
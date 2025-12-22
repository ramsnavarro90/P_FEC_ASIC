// tb_macros.svh

`define TB_START\
  $display("[%0t] Start simulation ", $time);

// `define TB_FINISH\
//   $display("[%0t] Finish simulation ", $time);\
//   $finish;

// Macro para generar un reloj con un período específico
`define TB_CLK(clk_signal, period) \
  initial clk_signal = 0; \
  always #(period/2) clk_signal = ~clk_signal;

`define WAIT_CLK(clk_signal, cycles)\
  repeat(cycles) @(posedge clk_signal);

// Macro para generar una señal de reset activa en bajo durante un tiempo determinado
`define TB_SRSTN(rst_signal, clk_signal, duration) \
  initial begin \
    rst_signal = 0; \
    repeat (duration) @(posedge clk_signal); \
    rst_signal = 1; \
  end

// Macro para configurar el volcado de la simulación en un archivo VCD
`define TB_DUMP(filename, scope, depth) \
  initial begin \
    $dumpfile(filename); \
    $dumpvars(depth, scope); \
  end

// Macro para finalizar la simulación después de un tiempo especificado
`define TB_FINISH(sim_time) \
  initial begin \
    #sim_time; \
    $display("Simulation finished at time %t", $time); \
    $finish; \
  end

// `define INFO(comp, msg, vars)\
//   $display("[%0t][``comp``] ``msg`` ", $time, ``vars``); \

// `define ERROR(comp, msg)\
//   $error("[%0t][``comp``] ``msg`` ", $time); \
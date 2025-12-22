
module ul_fec_engine (
  input  logic clk,
  input  logic rst_n,
  input  logic ul_in,
  input  logic ul_en,
  
  output logic [UART_MDW-1:0] ul_data_out [2**UART_FAW-1:0], // 8-bit vector x 8 items = 64
  output logic ul_data_valid
);


endmodule
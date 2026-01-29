`include "defines.svh"
//`include "crc.sv"
//`include "fec.sv"

module dl_fec_engine (
  input  logic                        clk,
  input  logic                        rst_n,
  input  logic [2**UART_RX_FAW-1:0][UART_MDW-1:0] data_in, // 8-bit vector x 7 items = 56 bits
  input  logic [7:0]                  msg_len,
  input  logic [3:0]                  msg_tag,
  // 64-bit Encoding cluster
  input  logic                        crc0_start,
  output logic                        enc0_done,
  output logic [CRC0_WIDTH-1:0]       crc0_data_out,
  output logic [ENC0_DATA_DEPTH-1:0]  enc0_row_p,
  output logic [ENC0_DATA_WIDTH-1:0]  enc0_col_p,
  // 16-bit Encoding cluster
  input  logic                        crc1_start,
  output logic                        enc1_done,
  output logic [CRC1_WIDTH-1:0]       crc1_data_out,
  output logic [ENC1_DATA_DEPTH-1:0]  enc1_row_p,
  output logic [ENC1_DATA_WIDTH-1:0]  enc1_col_p
  );
  
  // 64-bit Encoding cluster
  
  logic [CRC0_DATA_WIDTH-1:0] crc0_data_in;
  logic                       crc0_done;
  
  assign crc0_data_in = {data_in[6][UART_MDW-1:0],
                         data_in[5][UART_MDW-1:0],
                         data_in[4][UART_MDW-1:0],
                         data_in[3][UART_MDW-1:0],
                         data_in[2][UART_MDW-1:0],
                         data_in[1][UART_MDW-1:0],
                         data_in[0][UART_MDW-1:0]}; 
  
  crc_generator_seq #(
    .DATA_WIDTH         (CRC0_DATA_WIDTH),
    .CRC_WIDTH          (CRC0_WIDTH),
    .POLY               (CRC0_POLY),
    .SEED               (CRC0_SEED),
    .XOR_OPS_PER_CYCLE  (CRC0_XOR_OPS_PER_CYCLE)
  ) crc_gen0_u (
    .clk                (clk),
    .rst_n              (rst_n),
    .start              (crc0_start),
    .data_in            (crc0_data_in),
    .crc_out            (crc0_data_out),
    .done               (crc0_done)
  );
  
  logic [ENC0_DATA_WIDTH-1:0][ENC0_DATA_DEPTH-1:0] enc0_data_in;

  assign enc0_data_in =  {crc0_data_out, // B7 CRC-8
                          data_in[6][UART_MDW-1:0],    // B6 D6
                          data_in[5][UART_MDW-1:0],    // B5 D5
                          data_in[4][UART_MDW-1:0],    // B4 D4
                          data_in[3][UART_MDW-1:0],    // B3 D3
                          data_in[2][UART_MDW-1:0],    // B4 D2
                          data_in[1][UART_MDW-1:0],    // B1 D1
                          data_in[0][UART_MDW-1:0]};   // B0 D0
  
  encoder #(
    .WIDTH              (ENC0_DATA_WIDTH),
    .DEPTH              (ENC0_DATA_DEPTH)
  ) encoder0_u (
    .clk                (clk),
    .rst_n              (rst_n),
    .data_in            (enc0_data_in),
    .start              (crc0_done),
    .done               (enc0_done),
    .row_parity         (enc0_row_p),
    .col_parity         (enc0_col_p)
  );
  
  
  // 16-bit Encoding cluster
  
  logic [CRC1_DATA_WIDTH-1:0] crc1_data_in;
  logic                       crc1_done;
  
  assign crc1_data_in = {msg_len, msg_tag}; 
  
  crc_generator_seq #(
    .DATA_WIDTH         (CRC1_DATA_WIDTH),
    .CRC_WIDTH          (CRC1_WIDTH),
    .POLY               (CRC1_POLY),
    .SEED               (CRC1_SEED),
    .XOR_OPS_PER_CYCLE  (CRC1_XOR_OPS_PER_CYCLE)
  ) crc_gen1_u (
    .clk                (clk),
    .rst_n              (rst_n),
    .start              (crc1_start),
    .data_in            (crc1_data_in),
    .crc_out            (crc1_data_out),
    .done               (crc1_done)
  );
  
  logic [ENC1_DATA_WIDTH-1:0][ENC1_DATA_DEPTH-1:0] enc1_data_in;
  
  assign enc1_data_in = {crc1_data_out, // 4-bit
                         msg_len,       // 8-bit
                         msg_tag};      // 4-bit

  encoder #(
    .WIDTH              (ENC1_DATA_WIDTH),
    .DEPTH              (ENC1_DATA_DEPTH)
  ) encoder1_u (
    .clk                (clk),
    .rst_n              (rst_n),
    .data_in            (enc1_data_in),
    .start              (crc1_done),
    .done               (enc1_done),
    .row_parity         (enc1_row_p),
    .col_parity         (enc1_col_p)
  );
  
  
endmodule


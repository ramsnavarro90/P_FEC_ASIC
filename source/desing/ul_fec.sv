`include "defines.svh"
//`include "crc.sv"
//`include "fec.sv"

module ul_fec_engine (
  input  logic                                  clk,
  input  logic                                  rst_n,
  // Output to Uplink Monitor
  output logic                                  uncor_err,
  // Input from Uplink Monitor
  input  logic                                  enc_used,
  input  logic [2**UART_RX_FAW-2:0][UART_MDW-1:0]  data_in,    // 56 bits = d0 to d55
  // Input to 64-bit Decoding cluster
  input  logic                                  enc0_start,
  input  logic [ENC0_DATA_DEPTH-1:0]            enc0_row_p, // r0 to r7
  input  logic [ENC0_DATA_WIDTH-1:0]            enc0_col_p, // c0 to c7
  output logic [ENC0_DATA_WIDTH-1:0][ENC0_DATA_DEPTH-1:0] enc0_data_cor,
  output logic                                  enc0_err_det,
  output logic                                  enc0_err_cor,
  input  logic [CRC0_WIDTH-1:0]                 crc0_data,  // d56 to d63
  output logic                                  crc0_done,
  output logic                                  crc0_valid,
  // Input to 16-bit Decoding cluster
  input  logic                                  enc1_start,
  input  logic [ENC1_DATA_DEPTH-1:0]            enc1_row_p, // r0 to r3
  input  logic [ENC1_DATA_WIDTH-1:0]            enc1_col_p, // c0 to c3
  output logic [ENC1_DATA_WIDTH-1:0][ENC1_DATA_DEPTH-1:0] enc1_data_cor,
  output logic                                  enc1_err_det,
  output logic                                  enc1_err_cor,
  input  logic [CRC1_WIDTH-1:0]                 crc1_data,  // d12 to d15
  output logic                                  crc1_done,
  output logic                                  crc1_valid
);
  
  // 64-bit Decoding cluster

  logic [ENC0_DATA_WIDTH-1:0][ENC0_DATA_DEPTH-1:0] enc0_data_in;
  logic enc0_done;
  //logic [ENC0_DATA_WIDTH-1:0][ENC0_DATA_DEPTH-1:0] enc0_data_cor;
  //logic enc0_err_det;
  //logic enc0_err_cor;
  logic [CRC0_DATA_WIDTH+CRC0_DATA_WIDTH-1:0] crc0_data_in;
  //logic crc0_valid;
  
  assign enc0_data_in = { crc0_data,
                          data_in[6][7:0],
                          data_in[5][7:0],
                          data_in[4][7:0],
                          data_in[3][7:0],
                          data_in[2][7:0],
                          data_in[1][7:0],
                          data_in[0][7:0]};

  assign crc0_data_in = { data_in[6][7:0],
                          data_in[5][7:0],
                          data_in[4][7:0],
                          data_in[3][7:0],
                          data_in[2][7:0],
                          data_in[1][7:0],
                          data_in[0][7:0],
                          crc0_data};

  decoder #(
    .WIDTH           (ENC0_DATA_WIDTH),
    .DEPTH           (ENC0_DATA_DEPTH)
  ) decoder0_u (
    .clk             (clk),
    .rst_n           (rst_n),
    .data_in         (enc0_data_in),
    .row_parity      (enc0_row_p),
    .col_parity      (enc0_col_p),
    .start           (enc0_start),
    .done            (enc0_done),
    .data_corrected  (enc0_data_cor),
    .error_detected  (enc0_err_det),
    .error_corrected (enc0_err_cor)
  );

  crc_verify_seq #(
    .DATA_WIDTH         (CRC0_DATA_WIDTH),
    .CRC_WIDTH          (CRC0_WIDTH),
    .POLY               (CRC0_POLY),
    .XOR_OPS_PER_CYCLE  (CRC0_XOR_OPS_PER_CYCLE)
  ) crc_verify0_u (
    .clk                (clk),
    .rst_n              (rst_n),
    .start              (enc0_done),
    .data_crc_in        (crc0_data_in),
    .crc_valid          (crc0_valid),
    .done               (crc0_done)
  );

  // 16-bit Decoding cluster

  logic [ENC1_DATA_WIDTH-1:0][ENC1_DATA_DEPTH-1:0] enc1_data_in;
  logic enc1_done;
  // logic [ENC1_DATA_WIDTH-1:0][ENC1_DATA_DEPTH-1:0] enc1_data_cor;
  // logic enc1_err_det;
  // logic enc1_err_cor;
  logic [CRC1_DATA_WIDTH+CRC1_DATA_WIDTH-1:0] crc1_data_in;
  //logic crc1_valid;
  
  assign enc1_data_in = { crc1_data, 
                          data_in[0][3:0],
                          data_in[1][3:0],
                          data_in[2][3:0]};

  assign crc1_data_in = { data_in[0][3:0],
                          data_in[1][3:0],
                          data_in[2][3:0],
                          crc1_data};

  decoder #(
    .WIDTH           (ENC1_DATA_WIDTH),
    .DEPTH           (ENC1_DATA_DEPTH)
  ) decoder1_u (
    .clk             (clk),
    .rst_n           (rst_n),
    .data_in         (enc1_data_in),
    .row_parity      (enc1_row_p),
    .col_parity      (enc1_col_p),
    .start           (enc1_start),
    .done            (enc1_done),
    .data_corrected  (enc1_data_cor),
    .error_detected  (enc1_err_det),
    .error_corrected (enc1_err_cor)
  );

  crc_verify_seq #(
    .DATA_WIDTH         (CRC1_DATA_WIDTH),
    .CRC_WIDTH          (CRC1_WIDTH),
    .POLY               (CRC1_POLY),
    .XOR_OPS_PER_CYCLE  (CRC1_XOR_OPS_PER_CYCLE)
  ) crc_verify1_u (
    .clk                (clk),
    .rst_n              (rst_n),
    .start              (enc1_done),
    .data_crc_in        (crc1_data_in),
    .crc_valid          (crc1_valid),
    .done               (crc1_done)
  );

  //assign uncor_err = (enc_used) ? enc1_err_det && !enc1_err_cor : enc0_err_det && !enc0_err_cor;
  assign uncor_err = (enc_used) ? (enc1_err_det && !enc1_err_cor && crc1_valid) : (enc0_err_det && !enc0_err_cor && crc0_valid);

endmodule
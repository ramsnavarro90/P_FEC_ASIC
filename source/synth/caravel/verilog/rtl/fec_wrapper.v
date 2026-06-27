// SPDX-FileCopyrightText: 2020 Efabless Corporation
// SPDX-License-Identifier: Apache-2.0

`default_nettype none

/*
 *-------------------------------------------------------------
 *
 * fec_wrapper
 *
 * Wrapper for the P_FEC_ASIC project (CPC+CRC FEC with UART).
 * Instantiates fec_top and connects it to the Caravel harness
 * via IO pads, Wishbone clock/reset, and Logic Analyzer probes.
 *
 * IO pad mapping:
 *   io_in[0]  <- uart_rx  (UART receive, from external device)
 *   io_in[1]  <- ul_in    (Uplink serial input, from external device)
 *   io_in[2]  <- ul_en    (Uplink enable, from external device)
 *   io_out[0] -> uart_tx  (UART transmit)
 *   io_out[1] -> dl_out   (Downlink serial output)
 *   io_out[2] -> dl_en    (Downlink enable)
 *   io_out[3] -> dl_ready (Downlink data ready flag)
 *
 *-------------------------------------------------------------
 */

module fec_wrapper #(
    parameter BITS = 16
)(
`ifdef USE_POWER_PINS
    inout VPWR,
    inout VGND,
`endif

    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    
    // IOs
    input  [2:0] io_in,
    output [3:0] io_out,
    output [3:0] io_oeb

);
  // System signals
  wire clk;
  wire rst_n;
  assign clk = wb_clk_i;
  assign rst_n = ~wb_rst_i; // Active-low reset for fec_top
  
  // IO pad direction control (io_oeb: 0 = output, 1 = input)
  assign io_oeb[0] = 1'b0;  // uart_tx  -> output
  assign io_oeb[1] = 1'b0;  // dl_out   -> output
  assign io_oeb[2] = 1'b0;  // dl_en    -> output
  assign io_oeb[3] = 1'b0;  // dl_ready -> output

  // Instantiate the FEC core
  fec_top fec_u (
    // System
    .clk      (clk),
    .rst_n    (rst_n),
    // IO Pads
    .uart_rx  (io_in[0]),
    .uart_tx  (io_out[0]),
    .dl_out   (io_out[1]),
    .dl_en    (io_out[2]),
    .dl_ready (io_out[3]),
    .ul_in    (io_in[1]),
    .ul_en    (io_in[2])
  );

  // Antenna protection for long Caravel IO pad to macro routes
  (* keep *) sky130_fd_sc_hd__diode_2 ANTENNA_io_in0   (.DIODE(io_in[0]));
  (* keep *) sky130_fd_sc_hd__diode_2 ANTENNA_io_in1   (.DIODE(io_in[1]));
  (* keep *) sky130_fd_sc_hd__diode_2 ANTENNA_io_in2   (.DIODE(io_in[2]));
  (* keep *) sky130_fd_sc_hd__diode_2 ANTENNA_wb_rst_i (.DIODE(wb_rst_i));

endmodule

`default_nettype wire


// Author: Navarro Lopez, Angel
// Project description:
//   Forward error correction (FEC) using cross-parity check (CPC) and CRC for error check
//   Downlink (TX) controls ASK RF module
//   Uplink (RX) monitors ASK RF module

`include "defines.svh"
`include "tb_macros.vh"

`timescale 1ns/1ps

module fec_top_tb;
  
  localparam SPI_CLK_DIV = `SPI_CLK_DIV;

  logic             clk;
  logic             rst_n;
  logic             mosi;
  logic             miso;
  logic             sclk;
  logic             csb;
  logic             ss;
  logic             dl_out;
  logic             dl_en;
  logic             ul_in;
  logic             ul_en;
  bit [7:0]         clk_div = SPI_CLK_DIV;
  
  // Check if SPI_CLK_DIV is divisible by 2 at elaboration/compilation time
  if (SPI_CLK_DIV % 2 != 0) begin
    $error("SPI Clock div shall be divisible by 2. SPI_CLK_DIV = %0d", SPI_CLK_DIV);
  end

  // SPI loopback
  assign miso = mosi;

  fec_top fec_u (
    .clk      (clk),
    .rst_n    (rst_n),
    .spi_miso (miso),
    .spi_mosi (mosi),
    .spi_sclk (sclk),
    .spi_csb  (csb),
    .spi_ss   (ss),
    .dl_out   (dl_out),
    .dl_en    (dl_en),
    .ul_in    (ul_in),
    .ul_en    (ul_en)
  );
  
  `TB_CLK(clk, 10)
  `TB_SRSTN(rst_n, clk, 1)
  `TB_DUMP("fec_top_tb.vcd", fec_top_tb, 0) 
  `TB_FINISH(50_000)
  
  initial begin
    
    `WAIT_CLK(clk, 5)
    $finish;
    
  end
  
  task mcu_spi_send_8b(bit[7:0] data);
    sclk = 0;
    miso = 0;
    for(int ii=0; ii<7; ii++)begin
      repeat(clk_div/2) @(posedge clk);
      sclk = ~sclk;
      miso = data[ii];
    end
    
        
  endtask
  

  
  endmodule
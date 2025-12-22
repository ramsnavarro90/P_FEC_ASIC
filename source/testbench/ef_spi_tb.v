`include "tb_macros.vh"
`include "ef_utils.v"
//`include "EF_SPI.v"
`include "spi.sv"
`timescale        1ns/1ps
 // https://github.com/efabless/EF_SPI
module EF_SPI_tb;
  localparam CDW = 8; // The width of the clock divider used to generate the SPI clock.
  localparam FAW = 3; // Log2 of the FIFO depth.
    
  reg             clk;
  reg             rst_n;
  reg             CPOL = 0; // SPI Clock Polarity.
  reg             CPHA = 0; // SPI CLock Phase.
  reg  [CDW-1:0]  clk_divider = 10; // The SPI clock divider; SPI clock frequency = System Clock Frequency /clk_divider.
  reg             wr = 0; // Write to the TX FIFO.
  reg             rd = 0; // Read from the RX FIFO.
  reg  [7:0]      datai;  // Data to place into the TX FIFO.
  wire [7:0]      datao;  // Data from the RX FIFO.
  reg             enable; // enable for spi master pulse generation
  wire            busy;   // spi busy flag.
  wire            done;   // spi done flag.
  wire            mosi;   // Master Out Slave In; this line carries data from the master device to theslave.
  wire            miso;   // Master In Slave Out; this line carries data from the slave device to themaster.
  wire            csb;    // Chip Select Bar; this signal selects the slave device to communicate with,typically active low.
  reg             ss = 0; // None
  wire            sclk;   // Serial Clock; this provides the clock signal that synchronizes data transferbetween master and slave devices.
    
  reg               rx_en = 1;        // Enable the RX FIFO.
  reg               rx_flush = 0; // Flush the RX FIFO.
  reg   [FAW-1:0]   rx_threshold; // RX FIFO level threshold.
  wire  [FAW-1:0]   rx_level;     // RX FIFO data level.
    
  reg               tx_flush = 0; // Flush the TX FIFO.
  reg   [FAW-1:0]   tx_threshold; // TX FIFO level threshold.
  wire  [FAW-1:0]   tx_level;     // TX FIFO data level.

  // Create a loopback
  assign miso = mosi;

  SPI #(
    .CDW        (CDW),
    .FAW        (FAW)
  ) MUV (
    .clk        (clk),
    .rst_n      (rst_n),
    .CPOL       (CPOL),
    .CPHA       (CPHA),
    .clk_divider(clk_divider),
    .wr         (wr),
    .rd         (rd),
    .datai      (datai),
    .datao      (datao),
    .enable     (enable),
    .busy       (busy),
    .done       (done),
    .tx_flush   (tx_flush),
    .rx_en      (rx_en),
    .rx_flush   (rx_flush),
    .miso       (miso),
    .mosi       (mosi),
    .csb        (csb),
    .ss         (ss),
    .sclk       (sclk)
  );

  `TB_CLK(clk, 10)
  `TB_SRSTN(rst_n, clk, 1)
  `TB_DUMP("EF_SPI_tb.vcd", EF_SPI_tb, 0) 
  `TB_FINISH(30_000)
  
  initial begin
    int data_cnt = 2**FAW;
    bit [7:0] data;
    enable = 0;
    @(posedge rst_n);
    `WAIT_CLK(clk, 2)

    rx_en = 1;
    enable = 1;

    @(posedge clk);
    
    $display("[%0t] Data to send: %0d bytes", $time, data_cnt);
    repeat(2) begin
      repeat(data_cnt) write_tx_fifo($urandom_range(0, 255));
      repeat(data_cnt) wait_done();
      repeat(data_cnt) read_rx_fifo();
      flush_rx_fifo();
    end
    `WAIT_CLK(clk, 5)
    $finish;
    
  end
  
  function void print_rx_fifo(int data_cnt);
    $display("[%0t] SPI.rx_fifo.array_reg", $time);
    for(int i=0; i<data_cnt; i++) begin
      $display("[%0d]: 0x%0h", i, MUV.rx_array_reg[i]);
    end
  endfunction
  
  task wait_done();
    static bit [FAW-1:0] wait_cnt;
    @(negedge done);
    $display("[%0t] Done event %0d", $time, wait_cnt++);
    print_rx_fifo(2**FAW);
  endtask
  
  task read_rx_fifo();
    static bit [FAW-1:0] read_cnt;
    @(negedge clk);
    rd = 1;
    $display("[%0t] Reading data from SPI.rx_fifo: %0d 0x%2h", $time, read_cnt++, datao);
    @(negedge clk);
    rd = 0;
  endtask
  
  task flush_rx_fifo();
    @(negedge clk);
    rx_flush = 1;
    $display("[%0t] SPI.rx_fifo flush!", $time);
    repeat(1) @(negedge clk);
    rx_flush = 0;
    print_rx_fifo(2**FAW);
  endtask

  task write_tx_fifo(logic[CDW-1:0] data);
    static bit [FAW-1:0] write_cnt;
    @(negedge clk);
    datai = data;
    wr = 1'b1;
    $display("[%0t] Write data in SPI.tx_fifo: %0d 0x%2h", $time, write_cnt++, data);
    @(negedge clk);
    wr = 1'b0;
  endtask

  
  endmodule
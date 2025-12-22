`include "tb_macros.vh"
`include "uart.sv"
`timescale 1ns/1ps

module ef_uart_tb;

    parameter MDW = 8;
    parameter FAW = 4;
    parameter SC = 8;
    parameter GFLEN = 4;

    // Signals
    logic clk, rst_n;
    logic en, tx_en, rx_en, rd, wr;
    logic [MDW-1:0] wdata;
    logic [MDW-1:0] rdata;
    logic [15:0] prescaler;
    logic [3:0] data_size;
    logic stop_bits_count;
    logic [2:0] parity_type;
    logic [3:0] txfifotr, rxfifotr;
    logic [MDW-1:0] match_data;
    logic [5:0] timeout_bits;
    logic loopback_en, glitch_filter_en;
    logic tx_fifo_flush, rx_fifo_flush;

    wire tx_empty, tx_full;
    wire tx_done, rx_done;
    wire [FAW-1:0] tx_level, rx_level;
    wire tx_level_below, rx_level_above;
    wire rx_empty, rx_full;
    wire break_flag, match_flag;
    wire frame_error_flag, parity_error_flag, overrun_flag, timeout_flag;
    wire rx, tx;
  
    logic [MDW-1:0]  rx_array_reg [2**FAW-1:0];
    logic [MDW-1:0]  tx_array_reg [2**FAW-1:0];
  
    // Loopback mode (optional, since loopback_en will do it)
    assign rx = tx; 


    // UART
    EF_UART #(
      .MDW              (MDW), 
      .FAW              (FAW),
      .SC               (SC),
      .GFLEN            (GFLEN)
    ) uart_u (
      .clk              (clk),
      .rst_n            (rst_n),
      .prescaler        (prescaler),
      .en               (en),
      .tx_en            (tx_en),
      .rx_en            (rx_en),
      .rd               (rd),
      .wr               (wr),
      .wdata            (wdata),
      .rdata            (rdata),
      .data_size        (data_size),
      .stop_bits_count  (stop_bits_count),
      .parity_type      (parity_type),
      .txfifotr         (txfifotr),
      .rxfifotr         (rxfifotr),
      .match_data       (match_data),
      .timeout_bits     (timeout_bits),
      .loopback_en      (loopback_en),
      .glitch_filter_en (glitch_filter_en),
      .tx_fifo_flush    (tx_fifo_flush),
      .rx_fifo_flush    (rx_fifo_flush),
      .tx_empty         (tx_empty),
      .tx_full          (tx_full),
      .tx_level         (tx_level),
      .tx_level_below   (tx_level_below),
   // .tx_done          (rx_done),
      .tx_array_reg     (tx_array_reg),
      
      .rx_empty         (rx_empty),
      .rx_full          (rx_full),
      .rx_level         (rx_level),
      .rx_level_above   (rx_level_above),
   // .rx_done          (rx_done),
      .rx_array_reg     (rx_array_reg),
      
      .break_flag       (break_flag),
      .match_flag       (match_flag),
      .frame_error_flag (frame_error_flag),
      .parity_error_flag(parity_error_flag),
      .overrun_flag     (overrun_flag),
      .timeout_flag     (timeout_flag),
      .rx               (rx),
      .tx               (tx)
    );
  
  `TB_CLK(clk, 10)
  `TB_SRSTN(rst_n, clk, 1)
  `TB_DUMP("ef_uart_tb.vcd", ef_uart_tb, 0) 
  //`TB_FINISH(130_000)
  
  initial begin
    int data_cnt = 2**FAW;
    //int data_cnt = 1;
    bit [7:0] data;
    
    en               = 0; 
    tx_en            = 0;
    rx_en            = 0;
    rd               = 0;
    wr               = 0;
    wdata            = 0;
    data_size        = 8;
    stop_bits_count  = 0;
    parity_type      = 3'b000;
    prescaler        = 16'd2;  // Adjust this for baudrate
    txfifotr         = 4'd1;
    rxfifotr         = 4'd1;
    match_data       = 8'hA5;
    timeout_bits     = 6'd63;
    loopback_en      = 0;
    glitch_filter_en = 0;
    tx_fifo_flush    = 0;
    rx_fifo_flush    = 0;
    
    @(posedge rst_n);
    `WAIT_CLK(clk, 2)

    rx_en = 1;
    tx_en = 1;
    en = 1;

    @(posedge clk);
    
    $display("[%0t] Data to send: %0d bytes", $time, data_cnt);
    repeat(1) begin
      repeat(data_cnt) write_tx_fifo($urandom_range(0, 255));
      wait_rx_full();
      repeat(data_cnt) read_rx_fifo();
      flush_rx_fifo();
    end
    `WAIT_CLK(clk, 5)
    $finish;
    
  end
  
  function void print_rx_fifo(int data_cnt);
      $display("[%0t] UART.rx_fifo.array_reg", $time);
    for(int i=0; i<data_cnt; i++) begin
      $display("[%0d]: 0x%0h", i, uart_u.rx_array_reg[i]);
    end
  endfunction
  
  task wait_rx_full();
    static bit [FAW-1:0] wait_cnt;
    wait (rx_full);
    $display("[%0t] UART.rx_fifo_full event %0d", $time, wait_cnt++);
    print_rx_fifo(2**FAW);
  endtask
  
  task read_rx_fifo();
    static bit [FAW-1:0] read_cnt;
    @(negedge clk);
    rd = 1;
    $display("[%0t] Reading data from UART.rx_fifo: %0d 0x%2h", $time, read_cnt++, rdata);
    @(negedge clk);
    rd = 0;
  endtask
  
  task flush_rx_fifo();
    @(negedge clk);
    rx_fifo_flush = 1;
    $display("[%0t] UART.rx_fifo flush!", $time);
    repeat(1) @(negedge clk);
    rx_fifo_flush = 0;
    print_rx_fifo(2**FAW);
  endtask

  task write_tx_fifo(logic[MDW-1:0] data);
    static bit [FAW-1:0] write_cnt;
    @(negedge clk);
    wdata = data;
    wr = 1'b1;
    $display("[%0t] Write data in UART.tx_fifo: %0d 0x%2h", $time, write_cnt++, data);
    @(negedge clk);
    wr = 1'b0;
  endtask
  
//     initial begin
//         $dumpfile("uart_tb.vcd");
//         $dumpvars(0, tb_ef_uart);

//         // Reset
//         rst_n = 0;
//         en = 0; tx_en = 0; rx_en = 0;
//         rd = 0; wr = 0;
//         wdata = 0;
//         data_size = 8;
//         stop_bits_count = 0;
//         parity_type = 3'b000;
//         prescaler = 16'd10;  // Adjust this for baudrate
//         txfifotr = 4'd1;
//         rxfifotr = 4'd1;
//         match_data = 8'hA5;
//         timeout_bits = 6'd63;
//         loopback_en = 1;
//         glitch_filter_en = 0;
//         tx_fifo_flush = 0;
//         rx_fifo_flush = 0;

//         #50;
//         rst_n = 1;
//         en = 1;
//         tx_en = 1;
//         rx_en = 1;

//         #50;

//         // Send a byte
//         wdata = 8'hC3;
//         wr = 1;
//         #10 wr = 0;

//         // Wait for data to arrive
//         wait (rx_level > 0);
//         #10;

//         rd = 1;
//         #10;
//         rd = 0;

//         $display("Received data: 0x%0h", rdata);
//         if (rdata == 8'hC3)
//             $display("UART Loopback Test PASSED");
//         else
//             $display("UART Loopback Test FAILED");

//         #100;
//         $finish;
//     end
  


endmodule

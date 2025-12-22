
`include "tb_macros.vh"
`include "fec.sv"
`timescale        1ns/1ps
module encoder_tb;
  
  localparam int WIDTH = 4;
  localparam int DEPTH = 4;
  logic [WIDTH-1:0][DEPTH-1:0] data_in;
  logic [DEPTH-1:0] 	       row_parity;
  logic [WIDTH-1:0]            col_parity;
  logic clk;
  logic rst_n;
  logic start;
  logic done;
  
  encoder #(
    .WIDTH    (WIDTH),
    .DEPTH    (DEPTH)
  ) encoder_i (
    .clk        (clk),
    .rst_n      (rst_n),
    .data_in    (data_in),
    .row_parity (row_parity),
    .col_parity (col_parity),
    .start      (start),
    .done       (done)
  );
  
  `TB_CLK(clk, 10)
  `TB_SRSTN(rst_n, clk, 1)
  `TB_DUMP("encoder_tb.vcd", encoder_tb, 0) 
  `TB_FINISH(1_000)
  
  initial begin
    start = 0;
    
    repeat(10) begin
      data_in = '{$urandom_range(0,8),
                  $urandom_range(0,8),
                  $urandom_range(0,8),
                  $urandom_range(0,8)};
      encode(data_in);
    end
  end
  
  task encode(logic [WIDTH-1:0][DEPTH-1:0] data_in);
    print_data_in();
    @(negedge clk);
    start = 1;
    @(posedge done);
    print_parity();
    @(negedge clk);
    start = 0;
  endtask
  
  function print_parity();
    $display("Parity bits matrices");
    $display("C |3|2|1|0");
    $display("%0b",col_parity);
    $display("R");
    for (int i = 0; i < WIDTH; i++)
      $display("%0d|%b",i, row_parity[i]);
    $display("\n");
  endfunction
  
  function print_data_in();
    $display("Data inpu matrix");
    $display("O |3|2|1|0");
    for (int i = 0; i < WIDTH; i++)
      $display("%0d| %b %b %b %b", i,data_in[i][3],data_in[i][2], data_in[i][1], data_in[i][0]);
    //$display("\n");
  endfunction
  
endmodule



// module encoder_tb;
  
//   localparam int WIDTH = 4;
//   localparam int DEPTH = 4;
//   logic [WIDTH-1:0][DEPTH-1:0] data_in;
//   logic [DEPTH-1:0] 	       row_parity;
//   logic [WIDTH-1:0]            col_parity;
  
//   encoder #(
//     .WIDTH    (WIDTH),
//     .DEPTH    (DEPTH)
//   ) encoder_i (
//     .data_in    (data_in),
//     .row_parity (row_parity),
//     .col_parity (col_parity)
//   );
  
//   initial begin
    
//     repeat(10) begin
//       data_in = '{$urandom_range(0,8),
//                   $urandom_range(0,8),
//                   $urandom_range(0,8),
//                   $urandom_range(0,8)};
//       encode(data_in);
//     end
//   end
  
//   task encode(logic [DATA_WIDTH-1:0][DATA_DEPTH-1:0] data_in);
//     print_data_in();
//     #10;
//     print_parity();
//   endtask
  
//   function print_parity();
//     $display("Parity bits");
//     $display("C |3|2|1|0");
//     $display("%0b",col_parity);
//     $display("R")
//     for (int i = 0; i < WIDTH; i++)
//       $display("%0d|%b",i, row_parity[i], row_parity[i], row_parity[i], row_parity[i]);
//     $display("\n");
//   endfunction
  
//   function print_data_in();
//     $display("Data inpu matrix");
//     $display("O |3|2|1|0");
//     for (int i = 0; i < 4; i++)
//       $display("%0d| %b %b %b %b", i,data_in[i][3],data_in[i][2], data_in[i][1], data_in[i][0]);
//     $display("\n");
//   endfunction
  
// endmodule
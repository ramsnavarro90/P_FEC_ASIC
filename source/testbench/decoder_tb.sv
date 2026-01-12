`include "tb_macros.vh"
`include "fec.sv"

module decoder_tb;

  localparam DATA_WIDTH = 4;
  localparam DATA_DEPTH = 4;
  logic clk, rst_n;
  
//   logic [DATA_WIDTH-1:0][DATA_DEPTH-1:0] data = '{4'b1111, 4'b1111, 4'b1111, 4'b1111};
//   logic [DATA_DEPTH-1:0] row_p  = 4'b0000;
//   logic [DATA_WIDTH-1:0] col_p  = 4'b0000;
  
  logic [DATA_WIDTH-1:0][DATA_DEPTH-1:0] data = '{4'b0111, 4'b1011, 4'b1101, 4'b1110};
  logic [DATA_DEPTH-1:0] row_p  = 4'b0000;
  logic [DATA_WIDTH-1:0] col_p  = 4'b0000;
  logic [3:0][3:0] data_out;
  logic err_det, err_corr, done, start;

  decoder # (
    .WIDTH       (DATA_WIDTH),
    .DEPTH       (DATA_DEPTH)
  ) decoder_i (
    .clk              (clk),
    .rst_n            (rst_n),
    .data_in          (data),
    .row_parity       (row_p),
    .col_parity       (col_p),
    .data_corrected   (data_out),
    .error_detected   (err_det),
    .error_corrected  (err_corr),
    .done	            (done),
    .start            (start)
    );
  `TB_DUMP("decoder_tb.vcd", decoder_tb, 0) 
  `TB_FINISH(5000)
  `TB_CLK(clk, 10)

    initial begin
      rst_n = 'b0;
      start = 'b0;
      #2;
      rst_n ='b1;
      #12
      
      // 4 data errors
      set_data_in('{'b0111, 'b1011, 'b1101, 'b1110}, 'b0000, 'b0000);
      toggle_start(2);
      @(posedge done);
      print_error();
      print_data_out();
      `WAIT_CLK(clk,4)
      
      // 3 data errors
      set_data_in('{'b1111, 'b1011, 'b1101, 'b1110}, 'b0000, 'b0000);
      toggle_start(2);
      @(posedge done);
      print_error();
      print_data_out();
      `WAIT_CLK(clk,4)
      
      // 2 data errors
      set_data_in('{'b1111, 'b1111, 'b1101, 'b1110}, 'b0000, 'b0000);
      toggle_start(2);
      @(posedge done);
      print_error();
      print_data_out();
      `WAIT_CLK(clk,4)
      
      // 1 data error
      set_data_in('{'b1111, 'b1111, 'b1111, 'b1110}, 'b0000, 'b0000);
      toggle_start(2);
      @(posedge done);
      print_error();
      print_data_out();
      `WAIT_CLK(clk,4)
      
      // 0 data errors
      set_data_in('{'b1111, 'b1111, 'b1111, 'b1111}, 'b0000, 'b0000);
      toggle_start(2);
      @(posedge done);
      print_error();
      print_data_out();
      `WAIT_CLK(clk,4)
      
      // 1 parity error
      set_data_in('{'b1111, 'b1111, 'b1111, 'b1111}, 'b1000, 'b0000);
      toggle_start(2);
      @(posedge done);
      print_error();
      print_data_out();
      `WAIT_CLK(clk,4)
      
      // 1 data error and 1 parity error
      set_data_in('{'b1111, 'b1111, 'b1111, 'b1110}, 'b0000, 'b0001);
      toggle_start(2);
      @(posedge done);
      print_error();
      print_data_out();
      `WAIT_CLK(clk,4)
      
      // 4 data errors again
      set_data_in('{'b0111, 'b1011, 'b1101, 'b1110}, 'b0000, 'b0000);
      toggle_start(2);
      @(posedge done);
      print_error();
      print_data_out();
      `WAIT_CLK(clk,4)
      
      $finish;
    end
  
  task toggle_start(int delay);
    start = 'b1;
    #delay;
    start = 'b0;
  endtask
  
  function set_data_in(logic [DATA_WIDTH-1:0][DATA_DEPTH-1:0] data_in, logic [DATA_DEPTH-1:0] row, logic [DATA_WIDTH-1:0] col);
    data = data_in;
    row_p  = row;
    col_p  = col;
    print_data_in();
  endfunction
  
  function print_data_in();
    $display("Data input matrix");
      $display("I |3|2|1|0");
      for (int i = 0; i < 4; i++)
        $display("%0d| %b %b %b %b", i,data[i][3],data[i][2], data[i][1], data[i][0]);
      $display("\n");
  endfunction;
  
  function print_error();
    $display("Detected error?  %s", err_det?"Yes":"No");
    $display("Corrected error? %s", err_corr?"Yes":"No");
    $display("Task completed/done? %s", done?"Yes":"No");
    $display("\n");
  endfunction
    
  function print_data_out();
    $display("Data output matrix");
      $display("O |3|2|1|0");
      for (int i = 0; i < 4; i++)
        $display("%0d| %b %b %b %b", i,data_out[i][3],data_out[i][2], data_out[i][1], data_out[i][0]);
      $display("\n");
  endfunction

endmodule


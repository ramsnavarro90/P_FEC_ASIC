`include "tb_macros.vh"
`include "fec.sv"

module fec_tb;

  localparam DATA_WIDTH = 4;
  localparam DATA_DEPTH = 4;
  
  logic [DATA_WIDTH-1:0][DATA_DEPTH-1:0] data = '{4'b0111, 4'b1111, 4'b1111, 4'b1110}; // con un error en fila 2, col 1
  logic [DATA_DEPTH-1:0] row_p  = 4'b0000;
  logic [DATA_WIDTH-1:0] col_p  = 4'b0000;
  //logic total_p      = 1'b0;

    logic [3:0][3:0] data_out;
    logic err_det, err_corr, complete;

  cpc_fec # (
    .WIDTH       (DATA_WIDTH),
    .DEPTH       (DATA_DEPTH)
  ) cpc_fec_u (
    .data_in          (data),
    .row_parity       (row_p),
    .col_parity       (col_p),
    .data_corrected   (data_out),
    .error_detected   (err_det),
    .error_corrected  (err_corr)
    // .complete	      (complete) // not used in cpc_fec
    );
  `TB_DUMP("fec.vcd", fec_tb, 0) 
  `TB_FINISH(100)

    initial begin
        #1;
      $display("Data input matrix");
      $display("I |3|2|1|0");
      for (int i = 0; i < 4; i++)
        $display("%0d| %b %b %b %b", i,data[i][3],data[i][2], data[i][1], data[i][0]);
      $display("\n");
      
      $display("Detected error?  %s", err_det?"Yes":"No");
      
      if(err_det) begin
        $display("Bit coordenate to flip:");
        $display("Row: %0d", cpc_fec_u.error_row);
        $display("Col: %0d", cpc_fec_u.error_col);
      end
      
      $display("Data output matrix");
      $display("O |3|2|1|0");
      for (int i = 0; i < 4; i++)
        $display("%0d| %b %b %b %b", i,data_out[i][3],data_out[i][2], data_out[i][1], data_out[i][0]);
      $display("Corrected error? %s", err_corr?"Yes":"No");
      //$display("Correction completed? %s", complete?"Yes":"No");
      $display("\n");
      
      $finish;
    end

endmodule


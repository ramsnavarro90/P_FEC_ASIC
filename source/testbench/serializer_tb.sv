`include "tb_macros.vh"
`include "ef_utils.v"
`include "deser.v"
 
module serializer_tb;

  localparam DATA_WIDTH = 32;
  localparam DATA_DEPTH = 8;
  localparam CLK_DIV    = 4;

  reg clk;
  reg rst_n;
  reg ready;
  reg [DATA_WIDTH-1:0] par_in_0;
  reg [DATA_WIDTH-1:0] par_in_1;
  reg [DATA_WIDTH-1:0] par_in_2;
  reg [DATA_WIDTH-1:0] par_in_3;
  reg [DATA_WIDTH-1:0] par_in_4;
  reg [DATA_WIDTH-1:0] par_in_5;
  reg [DATA_WIDTH-1:0] par_in_6;
  reg [DATA_WIDTH-1:0] par_in_7;
  reg [$clog2(CLK_DIV):0] clk_divider;
  wire serial_out, serial_en;
  wire complete;
  wire [$clog2(DATA_WIDTH)-1:0] bit_count;
  wire [$clog2(DATA_DEPTH)-1:0] sample_count;
  
  serializer #(
    .DATA_WIDTH   (DATA_WIDTH),
    .DATA_DEPTH   (DATA_DEPTH),
    .DIV_WIDTH    ($clog2(CLK_DIV)+1)
) serializer_inst (
    .clk          (clk),
    .rst_n        (rst_n),
    .ready        (ready),
    .par_in       ({par_in_0, par_in_1, par_in_2, par_in_3, par_in_4, par_in_5, par_in_6, par_in_7}),
    .clk_div      (clk_divider),
    .serial_out   (serial_out),
    .serial_en    (serial_en),
    .complete     (complete),
    .bit_count    (bit_count),
    .sample_count (sample_count)
);


  `TB_CLK(clk, 10)
  //`TB_SRSTN(rst_n, clk, 5)
  `TB_DUMP("serializer_tb.vcd", serializer_tb, 0) 
  //`TB_FINISH(50_000)

  initial begin
    // Initialize signals
    rst_n = 0;
    ready = 0;
    clk_divider = CLK_DIV;
    #20;

    rst_n = 1;

    repeat(4) begin
      load_pdata();
      #50;
    end

    $display("Serialization complete.");
    #10;
    $finish;
  end

    //Monitor output
    always @(posedge clk) begin
      if (serial_out)
          $display("Time %0tns: serial_out = %b (bit %0d of word %0d)", $time, serial_out, bit_count, sample_count);
    end
  
  task load_pdata();
    // Load test data
//     par_in_0 = 'hffff_ffff;
//     par_in_1 = 'haaaa_aaaa;
//     par_in_2 = 'h5555_5555;
//     par_in_3 = 'h0000_0000;
//     par_in_4 = 'hffff_0000;
//     par_in_5 = 'hffff_aaaa;
//     par_in_6 = 'h5555_ffff;
//     par_in_7 = 'h0000_0000;
    
    par_in_0 = 'haaaa_aaaa;
    par_in_1 = 'haaaa_aaaa;
    par_in_2 = 'haaaa_aaaa;
    par_in_3 = 'haaaa_aaaa;
    par_in_4 = 'haaaa_aaaa;
    par_in_5 = 'haaaa_aaaa;
    par_in_6 = 'haaaa_aaaa;
    par_in_7 = 'haaaa_aaaa;
    
    $display("par_in 0x%0h", serializer_inst.par_in);
    // Start serialization
    #10;
    ready = 1;
    #10;
    ready = 0;
    
    // Wait for complete signal
    wait(complete);

  endtask

endmodule

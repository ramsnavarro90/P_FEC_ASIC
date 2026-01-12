
module encoder # (
    parameter int WIDTH = 4,
    parameter int DEPTH = 4
 )(
  input  logic                          clk,
  input  logic                          rst_n,
  input  logic [WIDTH-1:0][DEPTH-1:0]   data_in,
  output logic [DEPTH-1:0]              row_parity,
  output logic [WIDTH-1:0]              col_parity,
  input  logic                          start,
  output logic                          done
);
  
  logic [DEPTH-1:0] row_parity_i;
  logic [WIDTH-1:0] col_parity_i;
  
  // Register parity bits for signal propagation
  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      row_parity <= 'b0;
      col_parity <= 'b0;
      done       <= 'b0;
    end
    else if(start) begin
      row_parity <= row_parity_i;
      col_parity <= col_parity_i;
      done       <= 'b1;
    end
    else begin
      row_parity <= row_parity;
      col_parity <= col_parity;
      done       <= 'b0;
    end
  end
  
  // Parity calc for rows
    always_comb begin
        for (int i = 0; i < DEPTH; i++) begin
          row_parity_i[i] = ^data_in[i]; // XOR per fila
        end
    end

    // Parity calc for columns
    always_comb begin
        for (int j = 0; j < WIDTH; j++) begin
            col_parity_i[j] = 1'b0;
            for (int i = 0; i < DEPTH; i++) begin
                col_parity_i[j] ^= data_in[i][j];
            end
        end
    end
  
endmodule


module decoder #(
    parameter int WIDTH = 4,
    parameter int DEPTH = 4
)(
  input  logic                          clk,
  input  logic                          rst_n,
  input  logic [WIDTH-1:0][DEPTH-1:0]   data_in,
  input  logic [DEPTH-1:0] 	            row_parity,
  input  logic [WIDTH-1:0]              col_parity,
  input  logic                          start,
  output logic                          done,
  output logic [WIDTH-1:0][DEPTH-1:0]   data_corrected,
  output logic                          error_detected,
  output logic                          error_corrected
);

  typedef enum logic [1:0] {
    S_IDLE,
    S_GET,
    S_DECODE,
    S_SET
  } dec_st_t;

  // Iteration data
  logic [WIDTH-1:0][DEPTH-1:0]  data_in_i;
  logic [WIDTH-1:0][DEPTH-1:0]  data_corrected_i;
  logic error_detected_i, error_detected_r, error_detected_r2;
  logic error_corrected_i, error_corrected_r, error_corrected_r2;
  logic done_i;
  logic [DEPTH-1:0] calc_row_parity;
  logic [WIDTH-1:0] calc_col_parity;
  
  // CPC FEC Instance
  cpc_fec #(
    .WIDTH            (WIDTH),
    .DEPTH            (DEPTH)
  ) cpc_fec_u (
    .data_in          (data_in_i),
    .row_parity       (row_parity),
    .col_parity       (col_parity),
    .calc_row_parity  (calc_row_parity),
    .calc_col_parity  (calc_col_parity),
    .data_corrected   (data_corrected_i),
    .error_detected   (error_detected_i),
    .error_corrected  (error_corrected_i)
  );
  
  // FSM Decoder state
  dec_st_t dec_st;
  
  assign done_i = (row_parity==calc_row_parity) && (col_parity==calc_col_parity) || (error_detected_i && !error_corrected_i);
  
  // ----------------- Decoder FSM -----------------
  
  // Next state logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      dec_st <= S_IDLE;
   
    else begin
      case (dec_st)
        S_IDLE:    dec_st <= (start) ? S_GET : S_IDLE;
        S_GET:     dec_st <= S_DECODE;
        S_DECODE:  dec_st <= (done_i) ? S_SET : S_DECODE;
        S_SET:     dec_st <= S_IDLE;
        default:   dec_st <= S_IDLE;
      endcase
      
    end
          
  end

  // Output logic
  always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Decoder outputs
      done              <= 1'b0;
      data_corrected    <= 1'b0;
      error_detected    <= 1'b0;
      error_corrected   <= 1'b0;
      // FEC instance
      data_in_i         <=  'b0;
      error_detected_r  <= 1'b0;
      error_detected_r2 <= 1'b0; 
      error_corrected_r <= 1'b0;
      error_corrected_r2<= 1'b0;
    end else begin
      case(dec_st)
        
        // Wait for decode task
        S_IDLE: begin
          // Decoder outputs
          done              <= 1'b0;
          data_corrected    <= data_corrected;
          error_detected    <= error_detected;
          error_corrected   <= error_corrected;
          // FEC instance
          data_in_i         <=  'b0;
          error_detected_r  <= 1'b0;
          error_detected_r2 <= 1'b0; 
          error_corrected_r <= 1'b0;
          error_corrected_r2<= 1'b0;
        end
        
        // Get data from decoder ports
        S_GET: begin
          // Decoder outputs
          done              <= 1'b0;
          data_corrected    <= data_corrected;
          error_detected    <= error_detected;
          error_corrected   <= error_corrected;
          // FEC instance
          data_in_i         <= data_in;
          error_detected_r  <= 'b0;
          error_detected_r2 <= 'b0; 
          error_corrected_r <= 'b0;
          error_corrected_r2<= 'b0;
        end
        
        // Decoding state
        S_DECODE: begin
          // Decoder outputs
          done              <= 1'b0;
          data_corrected    <= data_corrected;
          error_detected    <= error_detected;
          error_corrected   <= error_corrected;
          // FEC instance
          data_in_i         <= data_corrected_i;
          error_detected_r  <= error_detected_i;
          error_detected_r2 <= error_detected_r;
          error_corrected_r <= error_corrected_i;
          error_corrected_r2<= error_corrected_r;
        end
        
        // Decode done, set data to decoder ports
        S_SET: begin
           // Decoder outputs
            done         <= done_i;
          // Handle when error was able / unable to correct
          if(error_detected_i && !error_corrected_i) begin
            data_corrected   <= data_in;
            error_detected   <= error_detected_r;
            error_corrected  <= error_corrected_r;
          end else begin
            data_corrected   <= data_corrected_i;
            error_detected   <= error_detected_r2;
            error_corrected  <= error_corrected_r2;
          end
            
            // FEC instance
            data_in_i         <= data_in_i;
            error_detected_r  <= error_detected_i;
            error_detected_r2 <= error_detected_r;
            error_corrected_r <= error_corrected_i;
            error_corrected_r2<= error_corrected_r;
        end
      endcase

    end
  end

endmodule


module cpc_fec  #(
    parameter int WIDTH = 4,
    parameter int DEPTH = 4
  ) (
  input  logic [WIDTH-1:0][DEPTH-1:0] data_in,
  input  logic [DEPTH-1:0]            row_parity,
  input  logic [WIDTH-1:0]            col_parity,
  output logic [DEPTH-1:0]            calc_row_parity,
  output logic [WIDTH-1:0]            calc_col_parity,
  output logic [WIDTH-1:0][DEPTH-1:0] data_corrected,
  output logic                        error_detected,
  output logic                        error_corrected
  );
  
  logic                               calc_total_parity;
  logic [$clog2(DEPTH)-1:0]           error_row;
  logic [$clog2(WIDTH)-1:0]           error_col;
  
  // Row parity calculation
  always_comb begin: row_parity_calc
    for (int i = 0; i < DEPTH; i++) begin
      calc_row_parity[i] = ^data_in[i]; // XOR de cada fila
    end
  end

  // Column parity calculation
  always_comb begin: col_parity_calc
    for (int j = 0; j < WIDTH; j++) begin
      calc_col_parity[j] = 1'b0;
      for (int i = 0; i < DEPTH; i++) begin
        calc_col_parity[j] ^= data_in[i][j];
      end
    end
  end

  // Total parity bit is the XOR of all row and column parities
  assign calc_total_parity = ^row_parity ^ ^col_parity;

  // Parity mismatch detection
  logic row_error_found, col_error_found;
  assign row_error_found = (row_parity != calc_row_parity);
  assign col_error_found = (col_parity != calc_col_parity);
  //assign error_detected  = row_error_found || col_error_found || (total_parity != calc_total_parity);
  assign error_detected  = row_error_found || col_error_found || (calc_total_parity);

  // Erronous bit detection and correction
  always_comb begin: error_detection_correction
    error_row = '0;
    error_col = '0;
    error_corrected = 0;
    data_corrected = data_in;

    if(!calc_total_parity) begin
      if (row_error_found || col_error_found) begin
        // Look for single row and column where parity differs
        for (int i = 0; i < DEPTH; i++)
          if (row_parity[i] != calc_row_parity[i])
            error_row = i;

        for (int j = 0; j < WIDTH; j++)
          if (col_parity[j] != calc_col_parity[j])
            error_col = j;

        // Correct bit in that position
        data_corrected[error_row][error_col] = ~data_in[error_row][error_col];
        error_corrected = 1;
      end
    end else begin
      error_corrected = 0;
    end
  end

  //assign done = error_corrected ? ((row_parity==calc_row_parity) && (col_parity==calc_col_parity)) : 1'b0;

endmodule

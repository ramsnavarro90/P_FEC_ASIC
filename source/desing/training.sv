module training_preamble #(
  parameter int PREAMBLE_COUNT = 8,
  parameter int DIV_WIDTH = 8
)(
  input logic clk,
  input logic rst_n,
  input logic [DIV_WIDTH-1:0] clk_div,
  input logic start,
  output logic done,
  output logic training
);

  localparam PREAMBLE_COUNT_INT = PREAMBLE_COUNT*2 - 1;

  typedef enum logic {
    S_IDLE     = 1'd0,
    S_TRAINING = 1'd1
  } state_t;
  state_t state;

  //logic [$clog2(PREAMBLE_COUNT):0] bit_count;
  logic done_int;
  logic [4:0] bit_count;
  logic [DIV_WIDTH-1:0] clk_cnt;
  
  // -------------------------------
  // Check parameter: PREAMBLE_COUNT must be power of 2
  // -------------------------------
 // if((PREAMBLE_COUNT == 0) || ((PREAMBLE_COUNT & (PREAMBLE_COUNT - 1)) != 0)) begin
 //   $error("trainee_preamble: PREAMBLE_COUNT (%0d) must be a power of 2!", PREAMBLE_COUNT);
 // end

  // Calculate done signal combinationally
  assign done = (state == S_TRAINING) && (bit_count == PREAMBLE_COUNT_INT) && (clk_cnt == clk_div);

  // FSM - Combinational state update
  always_comb begin
    case (state)
      S_IDLE:      state <= (start) ? S_TRAINING : S_IDLE;
      S_TRAINING:  state <= (done_int)  ? S_IDLE : S_TRAINING;
      default:     state <= S_IDLE;
    endcase
  end

  // Serializer logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      training      <= 1'b0;
      clk_cnt       <=  'b0;
      done_int          <= 1'b0;
      bit_count     <=  'b0;
    end else begin
      case (state)
        S_IDLE: begin
          if(start)
            training    <= 1'b0;
          else
            training    <= 1'b1;
          clk_cnt     <=  'b0;
          done_int        <= 1'b0;
          bit_count   <=  'b0;
        end

        S_TRAINING: begin
          training     <= training;

        //  if (clk_cnt == (clk_div-'b1)) begin
          if (clk_cnt == (clk_div)) begin
            clk_cnt <= 0;
            training <= ~training;

            if (bit_count == PREAMBLE_COUNT_INT) begin  
              bit_count <= 'b0;
              done_int      <= 'b1;
            end else begin
              bit_count <= bit_count + 1'b1;
            end

          end
          else begin
            clk_cnt <= clk_cnt + 1'b1;
          end
        end
      endcase
    end
  end

endmodule



module training_detector #(
  parameter int PREAMBLE_COUNT = 8,
  parameter int DIV_WIDTH = 8
)(
  input  logic clk,
  input  logic rst_n,
  output logic [DIV_WIDTH-1:0] clk_div,
  input  logic start,
  output logic done,
  input  logic training,
  input  logic enable
);

  typedef enum logic {
    S_IDLE        = 1'd0,
    S_TRAINING    = 1'd1
  } state_t;
  state_t state;

  logic training_prev, training_negedge;
  logic [$clog2(PREAMBLE_COUNT):0] training_negedge_count;
  logic [DIV_WIDTH-1:0] clk_cnt;
  
  // FSM - Sequential state update

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= S_IDLE;
    else begin
      case (state)
        S_IDLE:      state <= (start) ? S_TRAINING : S_IDLE;
        S_TRAINING:  state <= (done)  ? S_IDLE : S_TRAINING;
        default:     state <= S_IDLE;
      endcase
    end
  end

  // Calculate done signal combinationally

  assign done = (state == S_TRAINING) && (training_negedge_count == PREAMBLE_COUNT);
  

  // Training posedge detection

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      training_prev <= 1'b0;
    end
    else begin
      training_prev <= training;
    end
  end

  assign training_negedge = ~training & training_prev;

  // Training negedge counter

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      training_negedge_count <= 'b0;
    end
    else begin
      if (state == S_TRAINING) begin
        if (training_negedge == 1'b1 && enable == 1'b1)
          training_negedge_count <= training_negedge_count + 1'b1;
        else
          training_negedge_count <= training_negedge_count;
      end
      else // S_IDLE
        training_negedge_count <= 'b0;
    end 
  end

  // Clock counter

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      clk_cnt <= 'b0;
      clk_div <= 'b0;
    end
    else begin     
      if (state == S_TRAINING) begin
        if (enable == 1'b1 && training == 1'b1)
          clk_cnt <= clk_cnt + 1'b1;
        else if (done == 1'b1)
          clk_div <= clk_cnt >> $clog2(PREAMBLE_COUNT); // Average clock count per bit
        else
          clk_cnt <= clk_cnt;
      end
      else begin // S_IDLE
        clk_cnt <= 'b0;
        clk_div <= 'b0;
      end
    end
  end

 endmodule
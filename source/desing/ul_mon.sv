import fec_pkg::*;

module uplink_monitor #(
  parameter int SERIAL_DIV_WIDTH   = 8
)(
  input  logic clk,
  input  logic rst_n,
  input  logic ul_in,
  input  logic ul_en
);

typedef enum logic [2:0] {
  S_IDLE                    = 3'd0,
  S_TRAINING_START          = 3'd1,
  S_TRAINING                = 3'd2,
  S_SAMPLING_MESSAGE_ID     = 3'd3,
  S_SAMPLING_MESSAGE_DATA   = 3'd5,
  S_DESERIALIZER            = 3'd6
} ul_state_t;
ul_state_t ul_state, next_ul_state;

typedef enum logic {
  MESSAGE_ID   = 1'b0,
  MESSAGE_DATA = 1'b1
} sampling_t;
sampling_t sampling;

logic training_start;
logic training_done;

// Current state
always_ff @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    ul_state <= S_IDLE;
  else
    ul_state <= next_ul_state;
end

// Next state logic
always_comb begin

  case(ul_state)
    S_IDLE: begin
        next_ul_state = S_TRAINING_START;
    end

    S_TRAINING_START: begin
      next_ul_state = S_TRAINING;
    end

    S_TRAINING: begin
      if(training_done) begin
        if (sampling == MESSAGE_ID)
          next_ul_state = S_SAMPLING_MESSAGE_ID;
        else // MESSAGE_DATA
          next_ul_state = S_SAMPLING_MESSAGE_DATA;
      end
      else
        next_ul_state = ul_state;
    end

    S_SAMPLING_MESSAGE_ID: begin
      next_ul_state = S_DESERIALIZER;
    end

    S_SAMPLING_MESSAGE_DATA: begin
      next_ul_state = S_DESERIALIZER;
    end

    S_DESERIALIZER: begin
      next_ul_state = S_IDLE;
    end

    default: begin
      next_ul_state = S_IDLE;
    end
  endcase
end

// Output logic
always_ff @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    training_start  <= 1'b0;
    sampling        <= MESSAGE_ID;
  end
  else begin
    case(ul_state)
      S_IDLE: begin
        training_start  <= 1'b0;
        sampling        <= MESSAGE_ID;
      end

      S_TRAINING_START: begin
        training_start <= 1'b1;
      end

      S_TRAINING: begin
        training_start <= 1'b0;
      end

      S_SAMPLING: begin
        //training_start <= training_start;
      end

      default: begin
        training_start  <= 1'b0;
        sampling        <= MESSAGE_ID;
      end
    endcase
  end
end


// Training Detector

training_detector #(
  .PREAMBLE_COUNT  (DL_PREAMBLE_COUNT),
  .DIV_WIDTH       (SERIAL_DIV_WIDTH)
) training_detector_u (
  .clk        (clk),
  .rst_n      (rst_n),
  .clk_div    (serial_clk_div),
  .start      (training_start),
  .done       (training_done),
  .training   (ul_in),
  .enable     (ul_en)
);

// Data sampler

// Packet Unscramble

// Deserializer


endmodule
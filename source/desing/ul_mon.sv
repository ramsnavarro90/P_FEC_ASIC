import fec_pkg::*;

module uplink_monitor #(
  parameter int SERIAL_DIV_WIDTH   = 8
)(
  input  logic                                  clk,
  input  logic                                  rst_n,
  input  logic                                  ul_in,
  input  logic                                  ul_en,
  // FEC UL FSM
  output logic [7:0]                            msg_cnt,
  // Input from UL FEC engine
  input  logic                                  ul_fec_enc_used,
  input  logic                                  ul_fec_done,
  input  logic                                  ul_fec_uncor_err,
  // Output to UL FEC engine
  output logic                                  enc_used,
  output logic                                  done,
  output logic [2**UART_RX_FAW-2:0][UART_MDW-1:0]  data_out,   // 56 bits = d0 to d55
  // Output to 64-bit Decoding cluster
  output logic [CRC0_WIDTH-1:0]                 crc0_data,  // d56 to d63
  output logic [ENC0_DATA_DEPTH-1:0]            enc0_row_p, // r0 to r7
  output logic [ENC0_DATA_WIDTH-1:0]            enc0_col_p, // c0 to c7
  // Output to 16-bit Decoding cluster
  output logic [CRC1_WIDTH-1:0]                 crc1_data,  // d12 to d15
  output logic [ENC1_DATA_DEPTH-1:0]            enc1_row_p, // r0 to r3
  output logic [ENC1_DATA_WIDTH-1:0]            enc1_col_p  // c0 to c3
);

typedef enum logic [2:0] {
  S_IDLE                  = 3'd0,
  S_TRAINING_START        = 3'd1,
  S_TRAINING_SAMPLING     = 3'd2,
  S_MESSAGE_ID_START      = 3'd3,
  S_MESSAGE_ID_SAMPLING   = 3'd4,
  S_MSG_LEN_GET           = 3'd5,
  S_MESSAGE_DATA_START    = 3'd6,
  S_MESSAGE_DATA_SAMPLING = 3'd7
} ul_state_t;
ul_state_t ul_state, next_ul_state;

typedef enum logic [1:0] {
  NONE         = 2'd0,
  MESSAGE_ID   = 2'd1,
  MESSAGE_DATA = 2'd2
} sampling_t;
sampling_t sampling;

logic training_start, training_done;
logic deser_start, deser_done;
logic [SERIAL_DIV_WIDTH-1:0] deser_clk_div;
logic [$clog2(ENC0_PAR_DATA_WIDTH):0] deser_width;
logic [$clog2(ENC0_PAR_DATA_DEPTH):0] deser_depth;
logic [SERIAL_DATA_DEPTH-1:0][SERIAL_DATA_WIDTH-1:0] deser_par_out;
logic [7:0] msg_len; //, msg_cnt;
logic [8:0] msg_cnt_p7;
logic uncor_err;

assign msg_cnt_p7 = msg_cnt + 8'd7;

// Current state
always_ff @(posedge clk or negedge rst_n) begin
  if(!rst_n)
    ul_state <= S_IDLE;
  else
    ul_state <= next_ul_state;
end

// Next state logic
always_comb begin 

  next_ul_state = ul_state;
  case(ul_state)
    
    S_IDLE: begin
      if(uncor_err)
        next_ul_state = S_IDLE;
      else
        next_ul_state = S_TRAINING_START;
    end

    S_TRAINING_START: begin
      next_ul_state = S_TRAINING_SAMPLING;
    end

    S_TRAINING_SAMPLING: begin
      if(training_done) begin
        case (sampling)
          MESSAGE_ID:    next_ul_state = S_MESSAGE_ID_START;
          MESSAGE_DATA:  next_ul_state = S_MESSAGE_DATA_START;
          default:       next_ul_state = S_IDLE;
        endcase
      end
      // else
      //   next_ul_state = next_ul_state;
    end

    S_MESSAGE_ID_START: begin
      next_ul_state = S_MESSAGE_ID_SAMPLING;
    end

    S_MESSAGE_ID_SAMPLING: begin
      if(deser_done)
        next_ul_state = S_MSG_LEN_GET;
      // else
      //   next_ul_state = next_ul_state;
    end

    S_MSG_LEN_GET: begin
      // We need to wait for UL FEC to be done, hardcoded for now
      if(ul_fec_done)
        if(ul_fec_uncor_err)
          next_ul_state = S_IDLE;
        else
          next_ul_state = S_TRAINING_START;
      // else
      //   next_ul_state = next_ul_state;
    end

    S_MESSAGE_DATA_START: begin
      next_ul_state = S_MESSAGE_DATA_SAMPLING;
    end

    S_MESSAGE_DATA_SAMPLING: begin
      if(deser_done)
        next_ul_state = S_TRAINING_START;
      // else
      //   next_ul_state = next_ul_state;
    end

    default: begin
      next_ul_state = S_IDLE;
    end
  endcase
end

// Output logic
always_ff @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    training_start   <= 1'b0;
    sampling         <= MESSAGE_ID;
    msg_len          <= 8'd0;
    msg_cnt          <= 8'd0;
    deser_start      <= 1'b0;
    uncor_err        <= 1'b0;
    done             <= 1'b0;
  end
  else begin
    case(ul_state)

      S_IDLE: begin
        training_start  <= 1'b0;
        sampling        <= MESSAGE_ID;
        msg_len         <= 8'd0;
        msg_cnt         <= 8'd0;
        deser_start     <= 1'b0;
        uncor_err       <= 1'b0;
        done            <= 1'b0;
      end

      S_TRAINING_START: begin
        done           <= 1'b0;
        training_start <= 1'b1;
      end

      S_TRAINING_SAMPLING: begin
        training_start <= 1'b0;
      end

      S_MESSAGE_ID_START: begin
        deser_start   <= 1'b1;
        // sampling      <= MESSAGE_ID;
      end

      S_MESSAGE_ID_SAMPLING: begin
        deser_start   <= 1'b0;
        if(deser_done)
          done      <= 1'b1;
        else
          done      <= 1'b0;
      end

      S_MSG_LEN_GET: begin
        done      <= 1'b0;
        // We need to extract msg_len after message id is decoded
        if(ul_fec_done) begin
          if(ul_fec_uncor_err) begin
            sampling    <= NONE;
            msg_len     <= 8'd0;
            uncor_err   <= 1'b1;
          end
          else begin
            sampling      <= MESSAGE_DATA;
            msg_len[0]    <= deser_par_out[1][1]; // Decode msg_len from deserialized data
            msg_len[1]    <= deser_par_out[1][3];
            msg_len[3:2]  <= deser_par_out[2][1:0];
            msg_len[5:4]  <= deser_par_out[0][1:0];
            msg_len[6]    <= deser_par_out[0][3];
            msg_len[7]    <= deser_par_out[1][0];
            uncor_err     <= 1'b0;
          end
        end
        else begin
          sampling    <= sampling;
          msg_len     <= msg_len;
          uncor_err   <= uncor_err;
        end
      end

      S_MESSAGE_DATA_START: begin
        deser_start   <= 1'b1;
        //msg_cnt       <= msg_cnt + 8'd7;
        msg_cnt       <= (msg_cnt_p7>=msg_len)? msg_len:msg_cnt_p7;
      end

      S_MESSAGE_DATA_SAMPLING: begin
        deser_start   <= 1'b0;
        if(deser_done) begin
          done          <= 1'b1;
          if(msg_cnt >= msg_len) begin
            sampling      <= MESSAGE_ID;
            msg_cnt       <= 8'd0;
          end
          else begin
            sampling      <= MESSAGE_DATA;
            msg_cnt       <= msg_cnt;
          end
        end
        else begin
          done          <= 1'b0;
          sampling      <= sampling;
          msg_cnt       <= msg_cnt;
        end
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
  .clk_div    (deser_clk_div),
  .start      (training_start),
  .done       (training_done),
  .training   (ul_in),
  .enable     (ul_en)
);

// Deserializer

always_comb begin: deser_params_u
  case(sampling)
    MESSAGE_ID: begin
      deser_width = (ENC1_PAR_DATA_WIDTH-1);
      deser_depth = (ENC1_PAR_DATA_DEPTH-1);
      enc_used    = 1'b1;
    end
    MESSAGE_DATA: begin
      deser_width = (ENC0_PAR_DATA_WIDTH-1);
      deser_depth = (ENC0_PAR_DATA_DEPTH-1);
      enc_used    = 1'b0;
    end
    default: begin
      deser_width = 'b0;
      deser_depth = 'b0;
      enc_used    = 1'b0;
    end
  endcase
end

deserializer #(
  .DATA_WIDTH  (SERIAL_DATA_WIDTH),
  .DATA_DEPTH  (SERIAL_DATA_DEPTH),
  .DIV_WIDTH   (SERIAL_DIV_WIDTH)
) deserializer_u (
  .clk          (clk),
  .rst_n        (rst_n),
  .start        (deser_start),
  .serial_in    (ul_in),
  .serial_en    (ul_en),
  .clk_div      (deser_clk_div),
  .width        (deser_width),
  .depth        (deser_depth),
  .par_out      (deser_par_out),
  .done         (deser_done)
);

// Packet Unscramble

packet_unscramble #(
  .DATA_WIDTH       (SERIAL_DATA_WIDTH),
  .DATA_DEPTH       (SERIAL_DATA_DEPTH)
) ul_packet_unscramble_u (
  .enc_used        (ul_fec_enc_used),
  .data_out        (data_out),
  .crc0_data       (crc0_data),
  .enc0_row_p      (enc0_row_p),
  .enc0_col_p      (enc0_col_p),
  .crc1_data       (crc1_data),
  .enc1_row_p      (enc1_row_p),
  .enc1_col_p      (enc1_col_p),
  .par_in          (deser_par_out)
);

endmodule
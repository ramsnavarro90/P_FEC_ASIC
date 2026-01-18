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
  // output logic                                  done,
  
  input  logic                                  msg_done,
  output logic                                  enc_used,
  output logic [2**UART_RX_FAW-2:0][UART_MDW-1:0] data_out,   // 56 bits = d0 to d55
  input  logic                                  data_rd,
  output logic [UL_FIFO_FAW-1:0]                data_level,
  // Output to 64-bit Decoding cluster
  output logic [CRC0_WIDTH-1:0]                 crc0_data,  // d56 to d63
  output logic [ENC0_DATA_DEPTH-1:0]            enc0_row_p, // r0 to r7
  output logic [ENC0_DATA_WIDTH-1:0]            enc0_col_p, // c0 to c7
  // Output to 16-bit Decoding cluster
  output logic [CRC1_WIDTH-1:0]                 crc1_data,  // d12 to d15
  output logic [ENC1_DATA_DEPTH-1:0]            enc1_row_p, // r0 to r3
  output logic [ENC1_DATA_WIDTH-1:0]            enc1_col_p  // c0 to c3
);

typedef enum logic [3:0] {
  S_IDLE                  = 4'd0,
  S_TRAINING_START        = 4'd1,
  S_TRAINING_SAMPLING     = 4'd2,
  S_MESSAGE_ID_START      = 4'd3,
  S_MESSAGE_ID_SAMPLING   = 4'd4,
  S_MESSAGE_ID_REG        = 4'd5,
  S_MESSAGE_LEN_GET           = 4'd6,
  S_MESSAGE_DATA_START    = 4'd7,
  S_MESSAGE_DATA_SAMPLING = 4'd8,
  S_MESSAGE_DATA_REG      = 4'd9
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
logic [SERIAL_DIV_WIDTH-1:0]          deser_clk_div;
logic [$clog2(ENC0_PAR_DATA_WIDTH):0] deser_width;
logic [$clog2(ENC0_PAR_DATA_DEPTH):0] deser_depth;
logic [SERIAL_DATA_DEPTH-1:0][SERIAL_DATA_WIDTH-1:0] deser_par_out;
logic [7:0]                     msg_len;
logic [8:0]                     msg_cnt_p7;
logic                           enc_used_i;
logic                           uncor_err;
// logic [2**UART_RX_FAW-2:0][UART_MDW-1:0] data_out;
logic [UART_RX_WIDTH-1:0]       unscrambled_data_out;
logic [CRC0_WIDTH-1:0]          crc_data_mux;
logic [ENC0_DATA_DEPTH-1:0]     enc_row_p_mux;
logic [ENC0_DATA_WIDTH-1:0]     enc_col_p_mux;
logic                           fifo_rd, fifo_wr;
// logic [1:0]                     fifo_cnt;
logic [UL_FIFO_WIDTH-1:0]       fifo_out;
logic [UL_FIFO_FAW-1:0]         fifo_level;
logic [CRC0_WIDTH-1:0]                 crc0_data_i;
logic [ENC0_DATA_DEPTH-1:0]            enc0_row_p_i;
logic [ENC0_DATA_WIDTH-1:0]            enc0_col_p_i;
logic [CRC1_WIDTH-1:0]                 crc1_data_i;
logic [ENC1_DATA_DEPTH-1:0]            enc1_row_p_i;
logic [ENC1_DATA_WIDTH-1:0]            enc1_col_p_i;

assign fifo_rd    = data_rd;
assign data_level = fifo_level;
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
    end

    S_MESSAGE_ID_START: begin
      next_ul_state = S_MESSAGE_ID_SAMPLING;
    end

    S_MESSAGE_ID_SAMPLING: begin
      if(deser_done)
        next_ul_state = S_MESSAGE_ID_REG;
    end

    S_MESSAGE_ID_REG: begin
      next_ul_state = S_MESSAGE_LEN_GET;
      // if(fifo_cnt == 'd2)
      //   next_ul_state = S_MESSAGE_LEN_GET;

    end

    S_MESSAGE_LEN_GET: begin
      // We need to wait for UL FEC to be done
      if(ul_fec_done)
        if(ul_fec_uncor_err)
          next_ul_state = S_IDLE;
        else
          next_ul_state = S_TRAINING_START;
    end

    S_MESSAGE_DATA_START: begin
      next_ul_state = S_MESSAGE_DATA_SAMPLING;
    end

    S_MESSAGE_DATA_SAMPLING: begin
      if(deser_done)
        next_ul_state = S_MESSAGE_DATA_REG;
    end

    S_MESSAGE_DATA_REG: begin
      next_ul_state = S_TRAINING_START;
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
    // done             <= 1'b0;
    fifo_wr          <= 1'b0;
    // fifo_cnt         <= 'b0;
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
        // done            <= 1'b0;
        fifo_wr         <= 1'b0;
        // fifo_cnt         <= 'b0;
      end

      S_TRAINING_START: begin
        // done           <= 1'b0;
        fifo_wr   <= 1'b0;
        training_start <= 1'b1;
      end

      S_TRAINING_SAMPLING: begin
        training_start <= 1'b0;
      end

      S_MESSAGE_ID_START: begin
        deser_start   <= 1'b1;
      end

      S_MESSAGE_ID_SAMPLING: begin
        deser_start   <= 1'b0;
        // if(deser_done)
        //   done      <= 1'b1;
        // else
        //   done      <= 1'b0;
      end

      S_MESSAGE_ID_REG: begin
        fifo_wr   <= 1'b1;

        // fifo_cnt <= fifo_cnt + 1'b1;

        // if(fifo_cnt == 'd0)
        //   fifo_wr   <= 1'b1;
        // else if(fifo_cnt == 'd1)
        //   fifo_wr   <= 1'b0;
        // else if(fifo_cnt == 'd2)
        //   fifo_cnt <= 'b0;
        // else
        //   fifo_cnt <= fifo_cnt + 1'b1;
      end

      S_MESSAGE_LEN_GET: begin // Register Message ID and get Msg len
        fifo_wr   <= 1'b0;
        // done      <= 1'b0;
        
        // Extract msg_len after message id is decoded from UL FEC Engine
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
        deser_start  <= 1'b0;
        if(deser_done) begin
          // done          <= 1'b1;
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
          // done          <= 1'b0;
          sampling      <= sampling;
          msg_cnt       <= msg_cnt;
        end
      end
      
      S_MESSAGE_DATA_REG: begin // Register Message data
        fifo_wr   <= 1'b1;
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
    MESSAGE_ID: begin // 16-bit Encoder
      deser_width = (ENC1_PAR_DATA_WIDTH-1);
      deser_depth = (ENC1_PAR_DATA_DEPTH-1);
      enc_used_i    = 1'b1;
    end
    MESSAGE_DATA: begin // 64-bit Encoder
      deser_width = (ENC0_PAR_DATA_WIDTH-1);
      deser_depth = (ENC0_PAR_DATA_DEPTH-1);
      enc_used_i    = 1'b0;
    end
    default: begin
      deser_width = 'b0;
      deser_depth = 'b0;
      enc_used_i    = 1'b1;
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
  // .enc_used        (ul_fec_enc_used),
  .enc_used        (enc_used_i && msg_done),
  .par_in          (deser_par_out),
  .data_out        (unscrambled_data_out),
  .crc0_data       (crc0_data_i),
  .enc0_row_p      (enc0_row_p_i),
  .enc0_col_p      (enc0_col_p_i),
  .crc1_data       (crc1_data_i),
  .enc1_row_p      (enc1_row_p_i),
  .enc1_col_p      (enc1_col_p_i)
);

// Data out FIFO
//if(!ul_fec_enc_used || !msg_done)
assign crc_data_mux  = (enc_used_i && msg_done)? {          {(CRC0_WIDTH-CRC1_WIDTH){1'b0}},crc1_data_i } :  crc0_data_i;
assign enc_row_p_mux = (enc_used_i && msg_done)? {{(ENC0_DATA_DEPTH-ENC1_DATA_DEPTH){1'b0}},enc1_row_p_i} : enc0_row_p_i;
assign enc_col_p_mux = (enc_used_i && msg_done)? {{(ENC0_DATA_WIDTH-ENC1_DATA_WIDTH){1'b0}},enc1_col_p_i} : enc0_col_p_i;

fifo #( 
  .DW             (UL_FIFO_WIDTH),
  .AW             (UL_FIFO_FAW)
) dataout_fifo_u (
  .clk            (clk),
  .rst_n          (rst_n),
  .rd             (fifo_rd),
  .wr             (fifo_wr),
  .wdata          ({enc_used_i,             // Encoder used for frame (Msg ID, Msg data)
                    unscrambled_data_out, // Data from unscrambler
                    crc_data_mux,
                    enc_row_p_mux,
                    enc_col_p_mux}),
  .rdata          (fifo_out),               // Data out
  .level          (fifo_level)
);

// Assing output data
assign enc_used   = fifo_out[SAMP_BIT];
assign crc0_data  = fifo_out[CRC0_END : CRC_START];
assign enc0_row_p = fifo_out[ROW0_END : ROW_START];
assign enc0_col_p = fifo_out[COL0_END : COL_START];
assign crc1_data  = fifo_out[CRC1_END : CRC_START];
assign enc1_row_p = fifo_out[ROW1_END : ROW_START];
assign enc1_col_p = fifo_out[COL1_END : COL_START];
assign data_out   = fifo_out[DATA_END : DATA_START];

endmodule
module serializer #(
  parameter integer DATA_WIDTH = 32,
  parameter integer DATA_DEPTH = 4,
  parameter integer DIV_WIDTH  = 8
)(
  input  logic                                  clk,
  input  logic                                  rst_n,
  input  logic                                  start,
  input  logic [DATA_DEPTH-1:0][DATA_WIDTH-1:0] par_in,
  input  logic [DIV_WIDTH-1:0]                  clk_div,
  input  logic [$clog2(DATA_WIDTH):0]           width,
  input  logic [$clog2(DATA_DEPTH):0]           depth,
  output logic                                  serial_out,
  output logic                                  serial_en,
  output logic                                  done,
  output logic [$clog2(DATA_WIDTH):0]           bit_count,
  output logic [$clog2(DATA_DEPTH):0]           sample_count
);

  typedef enum logic [1:0] {
    S_IDLE      = 2'd0,
    S_SERIALIZE = 2'd1
  } state_t;
  state_t state;

  logic [DATA_DEPTH-1:0][DATA_WIDTH-1:0] par_in_r;
  logic [$clog2(DATA_WIDTH):0]         width_r;
  logic [$clog2(DATA_DEPTH):0]         depth_r;
  
  logic [DIV_WIDTH-1:0] clk_cnt;

  // FSM - sequential state update
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= S_IDLE;
    else begin
      case (state)
        S_IDLE:      state <= (start) ? S_SERIALIZE : S_IDLE;
        S_SERIALIZE: state <= (done) ? S_IDLE : S_SERIALIZE;
        default:     state <= S_IDLE;
      endcase
    end
  end

  // Serializer logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      serial_out    <= 0;
      serial_en     <= 0;
      clk_cnt       <= 0;
      bit_count     <= 0;
      sample_count  <= 0;
      done          <= 0;
      par_in_r      <= 'b0;
      width_r       <= 'b0;
      depth_r       <= 'b0;
    end else begin
      case (state)
        S_IDLE: begin
          serial_out    <= 0;
          serial_en     <= 0;
          clk_cnt       <= 0;
          bit_count     <= 0;
          sample_count  <= 0;
          done          <= 0;
          if (start) begin
            par_in_r <= par_in;
            width_r  <= width;
            depth_r  <= depth;
          end
          else begin
            par_in_r <= par_in_r;
            width_r  <= width_r;
            depth_r  <= depth_r;
          end
        end

        S_SERIALIZE: begin
          serial_en     <= 1;
          serial_out    <= par_in_r[sample_count][bit_count];

          if (clk_cnt == (clk_div)) begin  
            clk_cnt <= 'b0;

            if (bit_count >= (width_r)) begin
              bit_count <= 'b0;

              if (sample_count >= (depth_r)) begin
                sample_count <= 'b0;
                done <= 1'b1;
              end
              else
                sample_count <= sample_count + 1'b1;
            end
            else
              bit_count <= bit_count + 1'b1;
          end
          else
            clk_cnt <= clk_cnt + 1'b1;
        end
      endcase
    end
  end

endmodule


module deserializer #(
  parameter integer DATA_WIDTH = 32,
  parameter integer DATA_DEPTH = 4,
  parameter integer DIV_WIDTH  = 8
)(
  input  logic                                  clk,
  input  logic                                  rst_n,
  input  logic                                  start,
  input  logic                                  serial_in,
  input  logic                                  serial_en,
  input  logic [DIV_WIDTH-1:0]                  clk_div,
  input  logic [$clog2(DATA_WIDTH):0]           width,
  input  logic [$clog2(DATA_DEPTH):0]           depth,
  output logic [DATA_DEPTH-1:0][DATA_WIDTH-1:0] par_out,
  output logic                                  done,
  output logic [$clog2(DATA_WIDTH):0]           bit_count,
  output logic [$clog2(DATA_DEPTH):0]           sample_count
);

  typedef enum logic [1:0] {
    S_IDLE         = 2'd0,
    S_SAMPLE_SYNC  = 2'd1,
    S_DESERIALIZE  = 2'd2,
    S_OFF_SYNC     = 2'd3
  } state_t;
  state_t state;

  logic [DIV_WIDTH-1:0] clk_cnt, clk_div_i;
  logic [$clog2(DATA_WIDTH):0] width_r;
  logic [$clog2(DATA_DEPTH):0] depth_r;
  logic deser_done;

  assign clk_div_i = clk_div-1'b1;

  // FSM - sequential state update
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= S_IDLE;
    else begin
      case (state)
        S_IDLE:          state <= (start) ? S_SAMPLE_SYNC : S_IDLE;
        S_SAMPLE_SYNC:   state <= (clk_cnt == (clk_div_i>>1)) ? S_DESERIALIZE : S_SAMPLE_SYNC;
        S_DESERIALIZE:   state <= (deser_done)  ? S_OFF_SYNC : S_DESERIALIZE;
        S_OFF_SYNC:      state <= (clk_cnt == (clk_div_i>>1)) ? S_IDLE : S_OFF_SYNC;
        default:         state <= S_IDLE;
      endcase
    end
  end

  //assign done = (sample_count == depth_r) && (bit_count == width_r);

  // Deserializer logic
  always_ff @(posedge clk or negedge rst_n) begin 
    if (!rst_n) begin
      clk_cnt       <= 'b0;
      width_r       <= 'b0;
      depth_r       <= 'b0;
      par_out       <= 'b0;
      bit_count     <= 'b0;
      sample_count  <= 'b0;
      done          <= 1'b0;
      deser_done    <= 1'b0;
    end else begin
      case (state)

        S_IDLE: begin
          par_out       <= par_out;
          // par_out       <= 'b0;  zeroes or par_out ??
          bit_count     <= 'b0;
          sample_count  <= 'b0;
          done          <= 1'b0;
          deser_done    <= 1'b0;
          if(start) begin
            width_r   <= width;
            depth_r   <= depth;
          end else begin
            width_r   <= width_r;
            depth_r   <= depth_r;
          end
        end

        S_SAMPLE_SYNC: begin
          // Wait for half clock cycle to align sampling
          if(clk_cnt == clk_div_i>>1)
            clk_cnt <= 0;
          else
            clk_cnt <= clk_cnt + 1'b1;
        end

        S_DESERIALIZE: begin
          //par_out[sample_count][bit_count] <= serial_in;

          if (serial_en && clk_cnt == (clk_div_i)) begin  
            clk_cnt <= 'b0;
            par_out[sample_count][bit_count] <= serial_in;

            if (bit_count == width_r) begin
              bit_count <= 'b0;

              if (sample_count == depth_r) begin
                sample_count  <= 'b0;
                deser_done    <= 1'b1;
              end
              else
                sample_count <= sample_count + 1'b1;
            end  
            else
              bit_count <= bit_count + 1'b1;
            
          end
          else
            clk_cnt <= clk_cnt + 1'b1;
        
        end

        S_OFF_SYNC: begin
          deser_done <= 1'b0;
          // Wait for half clock cycle to align sampling
          if(clk_cnt == clk_div_i>>1) begin
            clk_cnt <= 0;
            done <= 1'b1;
          end
          else
            clk_cnt <= clk_cnt + 1'b1;
        end
      endcase
    end
  end

  endmodule

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
    IDLE     = 2'd0,
    TRANSMIT = 2'd1
  } state_t;
  state_t state;

  logic [DATA_DEPTH-1:0][DATA_WIDTH-1:0] par_in_r;
  logic [$clog2(DATA_WIDTH):0]         width_r;
  logic [$clog2(DATA_DEPTH):0]         depth_r;
  
  logic [DIV_WIDTH-1:0] clk_cnt;

  // FSM - sequential state update
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= IDLE;
    else begin
      case (state)
        IDLE:      state <= (start) ? TRANSMIT : IDLE;
        TRANSMIT:  state <= (done) ? IDLE : TRANSMIT;
        default:   state <= IDLE;
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
        IDLE: begin
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
          
        end

        TRANSMIT: begin
          serial_en     <= 1;
          serial_out    <= par_in_r[sample_count][bit_count];

         //if (clk_cnt == (clk_div-'b1)) begin
          if (clk_cnt == (clk_div)) begin  
            clk_cnt <= 0;
//             $display("[%0t] par_in: %0b", $time, par_in);
//             $display("[%0t] par_in_r: %0b", $time, par_in_r);
//             $display("[%0t] serial_out: %0b sample_count: %0d bit_count: %0d", $time, serial_out, sample_count, bit_count);

          //if (bit_count == (DATA_WIDTH-1)) begin
          //if (bit_count >= (width_r-1'b1)) begin
            if (bit_count >= (width_r)) begin
              bit_count <= 0;

            //if (sample_count == (DATA_DEPTH-1)) begin
            //if (sample_count >= (depth_r-1'b1)) begin
              if (sample_count >= (depth_r)) begin
                sample_count <= 0;
                done <= 1;
              end else begin
                sample_count <= sample_count + 1;
              end
            end else begin
              bit_count <= bit_count + 'b1;
            end

          end else begin
            clk_cnt <= clk_cnt + 'b1;
          end
        end
      endcase
    end
  end

endmodule


module deserializer #(
  parameter integer DATA_WIDTH = 32,
  parameter integer DATA_DEPTH = 4
)(
  input  logic                                  clk,
  input  logic                                  rst_n,
  input  logic                                  start,
  input  logic                                  serial_in,
  input  logic                                  serial_en,
  output logic [DATA_DEPTH-1:0][DATA_WIDTH-1:0] par_out,
  output logic                                  done
);

  typedef enum logic [1:0] {
    IDLE     = 2'd0,
    RECEIVE  = 2'd1
  } state_t;
  state_t state;

  logic [$clog2(DATA_WIDTH):0]         bit_count;
  logic [$clog2(DATA_DEPTH):0]         sample_count;

  // FSM - sequential state update
  // always_ff @(posedge clk or negedge rst_n) begin
  //   if (!rst_n)
  //     state <= IDLE;
  //   else begin
  //     case (state)
  //       IDLE:      state <= (serial_en) ? RECEIVE : IDLE;
  //       RECEIVE:   state <= (done) ? IDLE : RECEIVE;
  //       default:   state <= IDLE;
  //     endcase
  //   end
  // end

  // Deserializer logic
  // always_ff @(posedge clk or negedge rst_n) begin 
  //   if (!rst_n) begin
  //     par_out       <= 'b0;
  //     bit_count     <= 0;
  //     sample_count  <= 0;
  //     done          <= 0;
  //   end else begin
  //     case (state)
  //       IDLE: begin
  //         par_out       <= par_out;
  //         bit_count     <= 0;
  //         sample_count  <= 0;
  //         done          <= 0;
  //       end

  //       RECEIVE: begin
  //         par_out[sample_count][bit_count] <= serial_in;

  //         if (serial_en) begin
  //           //if (bit_count == (DATA_WIDTH-1)) begin
  //           if (bit_count >= (DATA_WIDTH)) begin
  //             bit_count <= 0;

  //             //if (sample_count == (DATA_DEPTH-1)) begin
  //             if (sample_count >= (DATA_DEPTH)) begin
  //               sample_count <= 0;
  //               done <= 1;
  //             end else begin
  //               sample_count <= sample_count + 1;
  //             end
  //           end else begin
  //             bit_count <= bit_count + 'b1;
  //           end
  //         end
  //       end
  //     endcase
  //   end
  // end

  endmodule

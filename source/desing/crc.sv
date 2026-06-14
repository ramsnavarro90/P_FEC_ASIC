
module crc_generator_seq #(
    parameter int                   DATA_WIDTH = 12,
    parameter int                   CRC_WIDTH  = 4,
    parameter logic [CRC_WIDTH:0]   POLY = 5'b10011,
    parameter logic [CRC_WIDTH-1:0] SEED = '0,
    parameter int                   XOR_OPS_PER_CYCLE = 1
) (
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    start,
    input  logic [DATA_WIDTH-1:0]   data_in,
    output logic [CRC_WIDTH-1:0]    crc_out,
    output logic                    done
);

    typedef enum logic [1:0] {
        S_IDLE,
        S_CRC_CALC,
        S_RESULT
    } state_t;
    state_t state, next_state;

    logic [DATA_WIDTH-1:0]          shift_reg;
    logic [CRC_WIDTH-1:0]           crc;
    logic [$clog2(DATA_WIDTH+1):0]  bit_counter;
    
    // Combinational signals for loop computation (unrolled stages)
    logic [DATA_WIDTH-1:0]          shift_reg_comb;
    logic [CRC_WIDTH-1:0]           crc_comb;
    logic [$clog2(DATA_WIDTH+1):0]  bit_counter_comb;

    // Stage arrays for generate-unroll (XOR_OPS_PER_CYCLE stages)
    logic [DATA_WIDTH-1:0]          shift_stage [0:XOR_OPS_PER_CYCLE];
    logic [CRC_WIDTH-1:0]           crc_stage   [0:XOR_OPS_PER_CYCLE];
    logic [$clog2(DATA_WIDTH+1):0]  bc_stage    [0:XOR_OPS_PER_CYCLE];

    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n)
            state <= S_IDLE;
        else
            state <= next_state;
    end

    always_comb begin
        next_state = state;
        case (state)
            S_IDLE:     if (start) next_state = S_CRC_CALC;
            S_CRC_CALC: if (bit_counter == 0) next_state = S_RESULT;
            S_RESULT:   next_state = S_IDLE;
            default:    next_state = S_IDLE;
        endcase
    end

    // Initial stage (stage 0)
    assign shift_stage[0] = shift_reg;
    assign crc_stage[0]   = crc;
    assign bc_stage[0]    = bit_counter;

    // Generate combinational unrolled stages
    genvar gi;
    generate
      for (gi = 0; gi < XOR_OPS_PER_CYCLE; gi = gi + 1) begin : gen_crc_stages
        wire feedback = (bc_stage[gi] > 'b0) ? (shift_stage[gi][DATA_WIDTH-1] ^ crc_stage[gi][CRC_WIDTH-1]) : 1'b0;
        wire [CRC_WIDTH-1:0] crc_shift = crc_stage[gi] << 1;
        assign crc_stage[gi+1] = (bc_stage[gi] > 'b0) ? (crc_shift ^ (feedback ? POLY[CRC_WIDTH-1:0] : {CRC_WIDTH{1'b0}})) : crc_stage[gi];
        assign shift_stage[gi+1] = (bc_stage[gi] > 'b0) ? (shift_stage[gi] << 1) : shift_stage[gi];
        assign bc_stage[gi+1] = (bc_stage[gi] > 'b0) ? (bc_stage[gi] - 1'b1) : bc_stage[gi];
      end
    endgenerate

    // Outputs from last stage
    assign crc_comb         = crc_stage[XOR_OPS_PER_CYCLE];
    assign shift_reg_comb   = shift_stage[XOR_OPS_PER_CYCLE];
    assign bit_counter_comb = bc_stage[XOR_OPS_PER_CYCLE];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            crc         <= SEED;
            shift_reg   <=  'b0;
            bit_counter <=  'b0;
            done        <= 1'b0;
            crc_out     <=  'b0;
        end
        else begin
            case (state)
                S_IDLE: begin
                    done        <= 1'b0;
                    if (start) begin
                        // $display("[%0t][DE-CRC-Gen] Data-in: 0x%0h ", $time, data_in);
                        crc         <= SEED;
                        shift_reg   <= data_in;
                        bit_counter <= DATA_WIDTH;
                    end
                end

                S_CRC_CALC: begin
                    crc         <= crc_comb;
                    shift_reg   <= shift_reg_comb;
                    bit_counter <= bit_counter_comb;
                end

                S_RESULT: begin
                //   $display("[%0t][DE-CRC-Gen] CRC-out: 0x%0h ", $time, crc);
                   crc_out  <= crc;
                   done     <= 1'b1;
                end
            endcase
        end
    end

endmodule



module crc_verify_seq #(
    parameter int                   DATA_WIDTH = 12,
    parameter int                   CRC_WIDTH  = 4,
    parameter logic [CRC_WIDTH:0]   POLY = 5'b10011,
    parameter int                   XOR_OPS_PER_CYCLE = 1
) (
    input  logic                            clk,
    input  logic                            rst_n,
    input  logic                            start,
    input  logic [DATA_WIDTH+CRC_WIDTH-1:0] data_crc_in,
    output logic                            crc_valid,
    output logic                            done
);

    typedef enum logic [1:0] {
        S_IDLE,
        S_CRC_CALC,
        S_RESULT
    } state_t;
    state_t state, next_state;

    logic [DATA_WIDTH+CRC_WIDTH-1:0]            shift_reg;
    logic [CRC_WIDTH-1:0]                       crc;
    logic [$clog2(DATA_WIDTH+CRC_WIDTH+1):0]    bit_counter;

    // Combinational signals for loop computation (unrolled stages)
    logic [DATA_WIDTH+CRC_WIDTH-1:0]            shift_reg_comb;
    logic [CRC_WIDTH-1:0]                       crc_comb;
    logic [$clog2(DATA_WIDTH+CRC_WIDTH+1):0]    bit_counter_comb;

    // Stage arrays for generate-unroll (XOR_OPS_PER_CYCLE stages)
    logic [DATA_WIDTH+CRC_WIDTH-1:0]            shift_stage_v [0:XOR_OPS_PER_CYCLE];
    logic [CRC_WIDTH-1:0]                       crc_stage_v   [0:XOR_OPS_PER_CYCLE];
    logic [$clog2(DATA_WIDTH+CRC_WIDTH+1):0]    bc_stage_v    [0:XOR_OPS_PER_CYCLE];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= S_IDLE;
        else
            state <= next_state;
    end

    always_comb begin
        next_state = state;
        case (state)
            S_IDLE:     if (start) next_state = S_CRC_CALC;
            S_CRC_CALC: if (bit_counter == 0) next_state = S_RESULT;
            S_RESULT:   next_state = S_IDLE;
        endcase
    end

    // Initial stage (stage 0)
    assign shift_stage_v[0] = shift_reg;
    assign crc_stage_v[0]   = crc;
    assign bc_stage_v[0]    = bit_counter;

    // Generate combinational unrolled stages
    genvar gj;
    generate
      for (gj = 0; gj < XOR_OPS_PER_CYCLE; gj = gj + 1) begin : gen_crc_verify_stages
        wire feedback_v = (bc_stage_v[gj] > 'b0) ? (shift_stage_v[gj][DATA_WIDTH+CRC_WIDTH-1] ^ crc_stage_v[gj][CRC_WIDTH-1]) : 1'b0;
        wire [CRC_WIDTH-1:0] crc_shift_v = crc_stage_v[gj] << 1;
        assign crc_stage_v[gj+1] = (bc_stage_v[gj] > 'b0) ? (crc_shift_v ^ (feedback_v ? POLY[CRC_WIDTH-1:0] : {CRC_WIDTH{1'b0}})) : crc_stage_v[gj];
        assign shift_stage_v[gj+1] = (bc_stage_v[gj] > 'b0) ? (shift_stage_v[gj] << 1) : shift_stage_v[gj];
        assign bc_stage_v[gj+1] = (bc_stage_v[gj] > 'b0) ? (bc_stage_v[gj] - 1'b1) : bc_stage_v[gj];
      end
    endgenerate

    // Outputs from last stage
    assign crc_comb         = crc_stage_v[XOR_OPS_PER_CYCLE];
    assign shift_reg_comb   = shift_stage_v[XOR_OPS_PER_CYCLE];
    assign bit_counter_comb = bc_stage_v[XOR_OPS_PER_CYCLE];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            crc         <= 'b0;
            shift_reg   <= 'b0;
            bit_counter <= 'b0;
            crc_valid   <= 1'b0;
            done        <= 1'b0;
        end
        else begin
            case (state)
                S_IDLE: begin
                    done        <= 1'b0;
                    if (start) begin
                        shift_reg   <= data_crc_in;
                        crc         <= 'b0;
                        bit_counter <= (DATA_WIDTH+CRC_WIDTH);
                        crc_valid   <= 1'b0;
                    end
                end

                S_CRC_CALC: begin
                    crc         <= crc_comb;
                    shift_reg   <= shift_reg_comb;
                    bit_counter <= bit_counter_comb;
                end

                S_RESULT: begin
                    crc_valid <= (crc == 'b0);
                    done      <= 1'b1;
                end
            endcase
        end
    end

endmodule

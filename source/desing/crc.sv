
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
    
    // Combinational signals for loop computation
    logic [DATA_WIDTH-1:0]          shift_reg_comb;
    logic [CRC_WIDTH-1:0]           crc_comb;
    logic [$clog2(DATA_WIDTH+1):0]  bit_counter_comb;
    logic                           feedback;

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

    // Combinational loop to compute CRC shifts
    always_comb begin
        shift_reg_comb = shift_reg;
        crc_comb = crc;
        bit_counter_comb = bit_counter;
        feedback = 1'b0;
        
        for (int i=0; i < XOR_OPS_PER_CYCLE; i++) begin
            if (bit_counter_comb > 'b0) begin
                feedback = shift_reg_comb[DATA_WIDTH-1] ^ crc_comb[CRC_WIDTH-1];
                crc_comb = crc_comb << 1;
                if (feedback)
                    crc_comb = crc_comb ^ POLY[CRC_WIDTH-1:0];
                shift_reg_comb = shift_reg_comb << 1;
                bit_counter_comb = bit_counter_comb - 1'b1;
            end
        end
    end

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

    // Combinational signals for loop computation
    logic [DATA_WIDTH+CRC_WIDTH-1:0]            shift_reg_comb;
    logic [CRC_WIDTH-1:0]                       crc_comb;
    logic [$clog2(DATA_WIDTH+CRC_WIDTH+1):0]    bit_counter_comb;
    logic                                       feedback;

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

    // Combinational loop to compute CRC shifts
    always_comb begin
        shift_reg_comb = shift_reg;
        crc_comb = crc;
        bit_counter_comb = bit_counter;
        feedback = 1'b0;
        
        for (int i=0; i < XOR_OPS_PER_CYCLE; i++) begin
            if (bit_counter_comb > 'b0) begin
                feedback = shift_reg_comb[DATA_WIDTH+CRC_WIDTH-1] ^ crc_comb[CRC_WIDTH-1];
                crc_comb = crc_comb << 1;
                if (feedback)
                    crc_comb = crc_comb ^ POLY[CRC_WIDTH-1:0];
                shift_reg_comb = shift_reg_comb << 1;
                bit_counter_comb = bit_counter_comb - 1'b1;
            end
        end
    end

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

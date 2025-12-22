`include "tb_macros.vh"
`include "crc.sv"
//`timescale 1ns/1ps

// module crc_tb;

//     // Parámetros de prueba
//     parameter int DATA_WIDTH = 12;
//     parameter int CRC_WIDTH  = 4;
//     parameter logic [CRC_WIDTH:0] POLY = 5'b10011;
//     parameter logic [CRC_WIDTH-1:0] SEED = '0;
//     parameter int XOR_OPS_PER_CYCLE = 4;

//     logic clk, rst, crc_ver_start, crc_gen_start;
//     logic [DATA_WIDTH-1:0] data_in;
//     logic [CRC_WIDTH-1:0] crc_out;
//     logic crc_ver_done, crc_gen_done;

//     logic [DATA_WIDTH + CRC_WIDTH - 1:0] data_crc_in;
//     logic crc_valid;


  
//     // Probar varios vectores
//     logic [DATA_WIDTH-1:0] test_vectors [3] = '{12'b101011001010, 12'b111111111111, 12'b000000000000};

  
//   `TB_CLK(clk, 10)
//   //`TB_SRSTN(rst_n, clk, 5)
//   `TB_DUMP("crc_tb.vcd", crc_tb, 0) 
//   `TB_FINISH(1_000)
  
//   // Instancias locales parametrizadas
//         crc_generator_seq #(
//             .DATA_WIDTH(DATA_WIDTH),
//             .CRC_WIDTH(CRC_WIDTH),
//             .POLY(POLY),
//             .SEED(SEED),
//             .XOR_OPS_PER_CYCLE(XOR_OPS_PER_CYCLE)
//         ) crc_gen (
//           .clk (clk),
//           .rst(rst), 
//           .start(crc_gen_start),
//           .data_in(data_in),
//           .crc_out(crc_out),
//           .done(crc_gen_done)
//         );

//         crc_verify_seq #(
//             .DATA_WIDTH(DATA_WIDTH),
//             .CRC_WIDTH(CRC_WIDTH),
//             .POLY(POLY),
//             .XOR_OPS_PER_CYCLE(XOR_OPS_PER_CYCLE)
//         ) crc_verify (
//           .clk (clk),
//           .rst(rst), 
//           .start(crc_ver_start),
//           .data_crc_in(data_crc_in),
//           .crc_valid(crc_valid),
//           .done(crc_ver_done)
//         );
  
  
//   initial begin
      
//       // Sim start
//         rst = 1; clk = 0; crc_ver_start = 0; crc_gen_start = 0;
//         @(negedge clk); rst = 0;
//         run_test();
//         $display("Tests PASSED");
//         $finish;
//     end

//       task run_test();

//         $display("\n--- Test con XOR_OPS_PER_CYCLE = %0d ---", XOR_OPS_PER_CYCLE);
//         `WAIT_CLK(clk,4);
        
//         foreach (test_vectors[i]) begin
            
//             data_in = test_vectors[i];
//             $display("CRC Gen");
//             @(negedge clk);
//             crc_gen_start = 1;
//             @(negedge clk);
//             crc_gen_start = 0;
//             // Esperar a que termine generación
//             wait(crc_gen_done);

//             $display("Data = %b | CRC = %b", data_in, crc_out);
//             `WAIT_CLK(clk,4);
//             // Verificar con el checker
//             $display("CRC Verify");
//             data_crc_in = {data_in, crc_out};
//             $display("Data+CRC: %b", data_crc_in);
//             @(negedge clk);
//             crc_ver_start = 1;
//             @(negedge clk);
//             crc_ver_start = 0;

//             wait(crc_ver_done);
//             $display("CRC Check: %s", crc_valid ? "PASS" : "FAIL");

//             assert(crc_valid) else begin
//                $fatal("CRC Check FAILED for vector %0b", data_in);
//             end
//             `WAIT_CLK(clk,4);
//         end
//     endtask

// endmodule


module crc_tb;

    // Parámetros actualizados
    parameter int DATA_WIDTH = 56;
    parameter int CRC_WIDTH  = 8;
    parameter logic [CRC_WIDTH:0] POLY = 9'b10000111;
    parameter logic [CRC_WIDTH-1:0] SEED = '0;
    parameter int XOR_OPS_PER_CYCLE = 8;

    logic clk, rst, crc_ver_start, crc_gen_start;
    logic [DATA_WIDTH-1:0] data_in;
    logic [CRC_WIDTH-1:0] crc_out;
    logic crc_ver_done, crc_gen_done;

    logic [DATA_WIDTH + CRC_WIDTH - 1:0] data_crc_in;
    logic crc_valid;

    // Nuevos vectores de 56 bits
    logic [DATA_WIDTH-1:0] test_vectors [3] = '{
        56'b11001100110011001100110011001100110011001100110011001100,
        56'b11111111111111110000000000000000111111110000000011111111,
        56'b00000000000000000000000000000000000000000000000000000000
    };

    `TB_CLK(clk, 10)
    `TB_DUMP("crc_tb.vcd", crc_tb, 0)
  `TB_FINISH(4_000)

    // Instancia CRC Generator
    crc_generator_seq #(
        .DATA_WIDTH(DATA_WIDTH),
        .CRC_WIDTH(CRC_WIDTH),
        .POLY(POLY),
        .SEED(SEED),
        .XOR_OPS_PER_CYCLE(XOR_OPS_PER_CYCLE)
    ) crc_gen (
        .clk(clk),
        .rst(rst),
        .start(crc_gen_start),
        .data_in(data_in),
        .crc_out(crc_out),
        .done(crc_gen_done)
    );

    // Instancia CRC Verifier
    crc_verify_seq #(
        .DATA_WIDTH(DATA_WIDTH),
        .CRC_WIDTH(CRC_WIDTH),
        .POLY(POLY),
        .XOR_OPS_PER_CYCLE(XOR_OPS_PER_CYCLE)
    ) crc_verify (
        .clk(clk),
        .rst(rst),
        .start(crc_ver_start),
        .data_crc_in(data_crc_in),
        .crc_valid(crc_valid),
        .done(crc_ver_done)
    );

    // Secuencia de prueba
    initial begin
        rst = 1; clk = 0;
        crc_ver_start = 0;
        crc_gen_start = 0;
        @(negedge clk);
        rst = 0;
        run_test();
        $display("✅ Todos los tests pasaron correctamente.");
        $finish;
    end

    task run_test();
        $display("\n--- Test con XOR_OPS_PER_CYCLE = %0d ---", XOR_OPS_PER_CYCLE);
        `WAIT_CLK(clk, 4);

        foreach (test_vectors[i]) begin
            data_in = test_vectors[i];
            $display("CRC Gen");
            @(negedge clk);
            crc_gen_start = 1;
            @(negedge clk);
            crc_gen_start = 0;

            wait(crc_gen_done);
            $display("Data = %056b", data_in);
            $display("CRC  = %08b", crc_out);

            `WAIT_CLK(clk, 2);

            $display("CRC Verify");
            data_crc_in = {data_in, crc_out};
            $display("Data+CRC = %064b", data_crc_in);

            @(negedge clk);
            crc_ver_start = 1;
            @(negedge clk);
            crc_ver_start = 0;

            wait(crc_ver_done);
            $display("CRC Check: %s", crc_valid ? "✅ PASS" : "❌ FAIL");

            assert(crc_valid) else begin
                $fatal("CRC Check FAILED for data vector: %0b", data_in);
            end

            `WAIT_CLK(clk, 4);
        end
    endtask

endmodule

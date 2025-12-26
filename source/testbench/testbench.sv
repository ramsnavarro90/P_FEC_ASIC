// Project description:
//   Telecomunicatio data transmitter with forward error correction (FEC)
//   using cross-parity check (CPC) codes and Cyclic redundancy check (CRC)
//   for error detection and correction.
//   Downlink drives data transmitter
//   Uplink monitors data reception
// Author: Navarro Lopez, Angel
// School mail: ramses.navarro@iteso.mx
// Work in progress...

`include "../desing/defines.svh"
`include "../testbench/tb_macros.svh"
import fec_pkg::*;

//`timescale 1ns/100ps
`timescale 1ns/1ns

module fec_top_tb;
  
  logic             clk;
  logic             rst_n;
  logic             uart_tx;
  logic             uart_rx = 1'b1;
  logic             dl_out;
  logic             dl_en;
  logic             dl_ready;
  logic             ul_in;
  logic             ul_en;
 
  bit [15:0]         uart_ps;
  int                uart_br;
  //bit [15:0]         uart_ps = (`SYS_CLK_FREQ / (uart_br * UART_SC))-1;
  bit [SERIAL_DIV_WIDTH-1:0] ser_clk_div = SERIAL_CLK_DIV;
  
// bit[15:0]         uart_ps = `SYS_CLK_FREQ / (uart_br * UART_SC);
  string test;
  
  fec_top fec_u (
    .clk      (clk),
    .rst_n    (rst_n),
    .uart_rx  (uart_rx),
    .uart_tx  (uart_tx),
    .dl_out   (dl_out),
    .dl_en    (dl_en),
    .dl_ready (dl_ready),
    .ul_in    (ul_in),
    .ul_en    (ul_en)
  );
  
  // Loopback mode selection
  initial begin
    if($test$plusargs("LOOPBACK")) begin
      assign ul_in = dl_out;
      assign ul_en = dl_en;
      $display("[%0t][TB] FEC Loopback mode is ON ", $time);
    end
    else begin
      assign ul_in = 1'b0;
      assign ul_en = 1'b0;
      $display("[%0t][TB] FEC Loopback mode is OFF ", $time);
    end
  end

  `TB_CLK(clk, 10)
  `TB_SRSTN(rst_n, clk, 1)
  `TB_DUMP("fec_top_tb.vcd", fec_top_tb, 0) 
  //`TB_FINISH(100_000_000)
  //`TB_FINISH(50_000)
  
   initial begin
     `TB_START
     `WAIT_CLK(clk, 2)
     uart_ps = fec_u.uart_prescaler;
     uart_br =  (`SYS_CLK_FREQ / ((uart_ps+1) * UART_SC));
     
     $display("=========   Design and test bench parameters   =========");
     $display("- Clock freq          : %0d MHz      ", `SYS_CLK_FREQ/1e6);
     $display("- Clock period        : %0d ns       ", `SYS_CLK_PERIOD);
     $display("- UART baudrate       : %0d bits/s   ", uart_br);
     $display("- UART prescaler      : %0d          ", uart_ps);
     $display("- UART_MDW            : %0d bits     ", UART_MDW);
     $display("- UART_FAW            : %0d items    ", UART_FAW);
     $display("- UART_SC             : %0d bits/baud", UART_SC);
     $display("- UART_GFLEN          : %0d          ", UART_GFLEN);
     $display("- SERIAL_CLK_DIV      : %0d clocks   ", SERIAL_CLK_DIV);
     $display("- SERIAL_DIV_WIDTH    : %0d bits     ", SERIAL_DIV_WIDTH);
     $display("========================================================");
    
     if($value$plusargs ("TEST=%s", test))
       $display ("[%0t][TB] Running test %s",$time ,test);
     else begin
       $display("[%0t][TB] No test is selected, finishing ", $time);
       $finish;
     end

         
    $monitor("[%0t][TB] fec_fsm.state: %s", $time, fec_u.u_fec_fsm.state.name());
    //downlink_monitor(/*clk, fec_u.dl_out*/);
    
    uart_setup();
    dl_ctrl_setup();
    `WAIT_CLK(clk, 5)
    
     case(test)
       "test_fec_tx_min_payload":      test_fec_data_tx(1);
       "test_fec_tx_8_payload":        test_fec_data_tx(8);
       "test_fec_tx_max_payload":      test_fec_data_tx(255);
       "test_fec_tx_invalid_payload":  test_fec_data_tx_invalid_payloads();
       "test_fec_tx_boundary_payload": test_fec_data_tx_boundary_payloads();
       "test_fec_tx_err_inj_mask_0":   test_fec_data_tx_err_inj(64'hbab1_cafe_dead_beef, 7);
       "test_fec_tx_err_inj_mask_1":   test_fec_data_tx_err_inj(64'hffff_ffff_ffff_ffff, 7);
       "test_fec_tx_err_inj_mask_2":   test_fec_data_tx_err_inj(64'h2, 7);
       "test_registers":               test_registers();
       "test_undef_command_error":     test_undef_command_error();
       "test_uart_rx_timeout_error":   test_uart_rx_timeout_error();
       "test_uart_rx_frame_error":     test_uart_rx_frame_error();
       "test_baudrates_configs":       test_baudrates_configs();
       default:  $display ("[%0t][TB] Unefined test %s",$time ,test);
     endcase
    
     `WAIT_CLK(clk, 50)
    $display("[%0t][TB] Finish simulation ", $time);
    $finish;
    
  end
  
  
  // ========================================================
  //                         TESTS
  // ========================================================
  
  task test_baudrates_configs();
    const int BAUD_TCS = 10;
    int baud_cfg, baud;
        
    $display("[%0t][TB-TEST] ======= UART Baudrates configuration =======", $time);
    $display("[%0t][TB-TEST] == Total configs: %0d  ==", $time, BAUD_TCS);
    
    for(int ii=1 ; ii<(BAUD_TCS+1); ii++) begin
      //baud_cfg = $urandom_range(0,10);
      baud_cfg = $urandom_range(6,9);
      case(baud_cfg)
        // Mid speed
        //0: baud =  4800;
        //1: baud =  9600;
        //2: baud =  19200;
        //3: baud =  38400;
        //4: baud =  57600;
        //5: baud =  115200;
        //Higher speeds
        6: baud =  230400;
        7: baud =  460800;
        8: baud =  576000;
        9: baud =  921600;
        // Non-standard
        //10: baud = $urandom_range(4800,921600);
        default: $fatal("[%0t][TB-TEST] Unsuported baudrate config: %0d ==", $time, baud_cfg);
      endcase
      
      $display("[%0t][TB-TEST] Config count: %0d baudrate: %0d %s ==", $time, ii, baud, (baud_cfg==10)?"(non-standard)":"(standard)");
      uart_setup_baudrate(baud, 1);
      test_fec_data_tx(8);
      
      $display("");
    end
    
  endtask
  
  
  // UART RX Frame Error (Stop bit error) ==================================================
  
  
  task test_uart_rx_frame_error();
    uart_error_t uart_error;
    logic[7:0] err_resp, err_code;
    const int TO_ERR_NUM = 30;
    bit[7:0] data;
    bit result;
    
    $display("[%0t][TB-TEST] ======= UART RX Frame error =======", $time);
    $display("[%0t][TB-TEST] == Total frame errors: %0d  ==", $time, TO_ERR_NUM);
    
    uart_error = UART_RX_FER;
    for(int ii=1; ii<(TO_ERR_NUM+1); ii++) begin
      $display("[%0t][TB-TEST] Frame error count: %0d  ==", $time, ii);
      data = $urandom_range(8'h0, 8'hff);
      uart_send_with_error(uart_error, data);  // UART TX Frame Error
      uart_receive_8b(err_resp[7:0]); // Err response command
      uart_receive_8b(err_code[7:0]); // Command result (Error code)
      
      // check for error response
      if(err_resp==CMD_ERR_RS)
        $display("[%0t][TB-TEST] FEC Error response command ID received is as expeted: %0d.", $time, CMD_ERR_RS);
      else begin
        $error("[%0t][TB-TEST] FEC Error response command ID received mismatches. Actual: %0d Expected: %0d", $time, err_resp, CMD_ERR_RS);
        result = 1;
      end
      // Check for error code
      if(err_code[2]==1'b1)
        $display("[%0t][TB-TEST] FEC Error response code received is as expeted: Flags [2] UART_RX_FER.", $time);
      else begin
        $error("[%0t][TB-TEST] FEC Error response code received mismatches. Does not flag [2] UART_RX_FER", $time, err_code);
        result = 1;
      end
      $display("");
    end
    
    `WAIT_CLK(clk, 20)
    $display("[%0t][TB-TEST] TEST %s", $time, result?"FAILED":"PASSED"); 
    $display("");
    
  endtask
    
  
  // UART RX Timeout Error =================================================================
  
  
  task test_uart_rx_timeout_error();
    uart_error_t uart_error;
    int data_lenght;
    logic[7:0] err_resp, err_code;
    const int TO_ERR_NUM = 30;
    bit result;
    
    $display("[%0t][TB-TEST] ======= UART RX Timeout error =======", $time);
    $display("[%0t][TB-TEST] == Total timeout errors: %0d  ==", $time, TO_ERR_NUM);
    
    for(int ii=1; ii<(TO_ERR_NUM+1); ii++) begin
      uart_error  = $urandom_range(UART_RX_RTO_COMMAND, UART_RX_RTO_DATA);
      data_lenght = $urandom_range(1, 30);
      
      $display("[%0t][TB-TEST] Timeout error count: %0d  ==", $time, ii);
      
      fec_data_transmit_rand_with_timeout_error(data_lenght, uart_error);
      uart_receive_8b(err_resp[7:0]); // Err response command
      uart_receive_8b(err_code[7:0]); // Command result (Error code)
      
      // check for error response
      if(err_resp==CMD_ERR_RS)
        $display("[%0t][TB-TEST] FEC Error response command ID received is as expeted: %0d.", $time, CMD_ERR_RS);
      else begin
        $error("[%0t][TB-TEST] FEC Error response command ID received mismatches. Actual: %0d Expected: %0d", $time, err_resp, CMD_ERR_RS);
        result = 1;
      end
      // Check for error code
      if(err_code==8'b010)
        $display("[%0t][TB-TEST] FEC Error response code received is as expeted: 2.", $time);
      else begin
        $error("[%0t][TB-TEST] FEC Error response code received mismatches. Actual: %0d Expected: 2", $time, err_code);
        result = 1;
      end
      $display("");
      //`WAIT_CLK(clk, 100)
      
    end
    
    `WAIT_CLK(clk, 20)
    $display("[%0t][TB-TEST] TEST %s", $time, result?"FAILED":"PASSED"); 
    $display("");
      
  endtask
  
  
  // Undefined command Error
  
  
  task test_undef_command_error();
    command_t command;
    logic[7:0] err_resp, err_code;
    const int CMDS_NUM = 30;
    bit result;
    
    $display("[%0t][TB-TEST] ======= Undefined command error response =======", $time);
    $display("[%0t][TB-TEST] == Commands count: %0d  ==", $time, CMDS_NUM);
    
    for(int ii=0; ii<CMDS_NUM; ii++) begin
      command = $urandom_range(5,15); // use undefined command ids
      fec_command_error(command, err_resp,  err_code);
      
      // check for error response
      if(err_resp==CMD_ERR_RS)
        $display("[%0t][TB-TEST] FEC Error response command ID received is as expeted: %0d.", $time, CMD_ERR_RS);
      else begin
        $error("[%0t][TB-TEST] FEC Error response command ID received mismatches. Actual: %0d Expected: %0d", $time, err_resp, CMD_ERR_RS);
        result = 1;
      end
      // Check for error code
      if(err_code[0]==1'b1)
        $display("[%0t][TB-TEST] FEC Error response code received is as expeted: 0.", $time);
      else begin
        $error("[%0t][TB-TEST] FEC Error response code received mismatches. Actual: %0d Expected: 0", $time, err_code);
        result = 1;
      end
      
    end
    
    `WAIT_CLK(clk, 20)
    $display("[%0t][TB-TEST] TEST %s", $time, result?"FAILED":"PASSED"); 
    $display("");
        
  endtask
  
  
  // Registers =============================================================================
  
  
  task test_registers();
    bit [31:0] wdata, rdata;
    bit [7:0] rsp_cmd, rsp_addr, rsp_code;
    reg_addr_t registers;
    bit result;
    const int REGS_TCS = 10;
    
    $display("[%0t][TB-TEST] ======= Register W-R =======", $time);
    $display("[%0t][TB-TEST] == Total registers: %0d  ==", $time, registers.num());  
    
    registers = registers.first(); // set first reg
    
    repeat(registers.num()) begin
      
      // Skip config registers
      if(registers inside{REG_ADDR_UART_PR, REG_ADDR_UART_CTRL, REG_ADDR_UART_CFG}) continue;
      
      for(int ii=1; ii<(REGS_TCS+1); ii++) begin
        $display("[%0t][TB-TEST] Register: %s Address: 0x%0h Access cnt: %0d", $time, registers.name(), registers, ii);
      
        wdata = $urandom_range(32'h0,32'h ffff_ffff); // Random data
        rdata = 32'b0;
      
        // Mask write data as per register bit lenght
        case(registers)
          REG_ADDR_DL_SER_CLK_DIV:     wdata = wdata[15:0];
          REG_ADDR_DL_ERR_INJ_ENABLE:  wdata = wdata[00:0];
          //REG_ADDR_UART_PR:            wdata = wdata[15:0];
          //REG_ADDR_UART_CTRL:          wdata = wdata[04:0];
          //REG_ADDR_UART_CFG:           wdata = wdata[13:0];
        endcase
        
        // Write
        fec_reg_write(registers, wdata, rsp_cmd, rsp_addr, rsp_code, 1);
        
        // Read
        fec_reg_read(registers, rdata, 1);
       
        // Check for data integrity
        if(wdata != rdata) begin
          $error("[%0t][TB-TEST] Register data mismatch. Written data: %0h Read data: %0h", $time, wdata, rdata);
          result = 1;
        end else begin
          $display("[%0t][TB-TEST] Register data match. Written data: %0h Read data: %0h", $time, wdata, rdata);
        end
        $display("");
      end // for
      
      registers = registers.next();
      
    end // repeat
    
    
    `WAIT_CLK(clk, 20)
    $display("[%0t][TB-TEST] TEST %s", $time, result?"FAILED":"PASSED"); 
    $display("");
  endtask
  
  
  // FEC data transmission with error injection ==========================================
  
  
  task test_fec_data_tx_err_inj(bit[63:0] mask, bit[7:0] payload);
    static bit [6:0] msg_pkts = payload/7+1;
    static bit [3:0] msg_tag = $urandom_range(0, 15);
    bit [7:0] rsp_cmd, rsp_addr, rsp_code, rsp_tag;
    //static bit [7:0] rsp_cmd, rsp_tag, rsp_code;
    
    $display("[%0t][TB-TEST] ====== Error Injection Mask =====", $time);
    $display("[%0t][TB-TEST] == Mask:        0x%0h       ==", $time, mask);
    $display("[%0t][TB-TEST] == Payload:     %0d         ==", $time, payload);
    $display("[%0t][TB-TEST] == Msg packets: %0d         ==", $time, msg_pkts);
    
    fec_reg_write(REG_ADDR_DL_ERR_INJ_MASK_1, mask[63:32], rsp_cmd, rsp_addr, rsp_code, 0);
    fec_reg_write(REG_ADDR_DL_ERR_INJ_MASK_0, mask[31:00], rsp_cmd, rsp_addr, rsp_code, 0);
    fec_reg_write(REG_ADDR_DL_ERR_INJ_ENABLE, 1, rsp_cmd, rsp_addr, rsp_code, 0);
    
    fec_data_transmit_rand(payload, msg_tag, rsp_cmd, rsp_tag, rsp_code);
    repeat(msg_pkts) @(negedge dl_en);
  endtask
  
  
  // FEC data Transmission
  
    
  task test_fec_data_tx(bit[7:0] msg_len);
    static bit [3:0] msg_tag = $urandom_range(0, 15);
    bit [7:0] rsp_cmd, rsp_tag, rsp_code;
    bit result;
    
    $display("[%0t][TB-TEST] ======= FEC data Transmission =======", $time);
    $display("[%0t][TB-TEST] ==== Payload: %0d bytes        ==", $time, msg_len);
    fec_data_transmit_rand(msg_len, msg_tag, rsp_cmd, rsp_tag, rsp_code);
    //@(negedge dl_en);
    //@(negedge dl_en);
    
    // check for response command
    if(rsp_cmd==CMD_FEC_RS)
      $display("[%0t][TB-TEST] FEC response command ID received is as expeted: %0d.", $time, CMD_FEC_RS);
    else begin
      $error("[%0t][TB-TEST] FEC response command ID received mismatches. Actual: %0d Expected: %0d", $time, rsp_cmd, CMD_FEC_RS);
      result = 1;
    end
    // check for response tag
    if(rsp_tag==msg_tag)
      $display("[%0t][TB-TEST] FEC response tag received is as expeted: %0d.", $time, msg_tag);
    else begin
      $error("[%0t][TB-TEST] FEC response tag received mismatches. Actual: %0d Expected: %0d", $time, rsp_tag, msg_tag);
      result = 1;
    end
    // Check for response code
    if(rsp_code==8'h0)
      $display("[%0t][TB-TEST] FEC response code received is as expeted: 0.", $time);
    else begin
      $error("[%0t][TB-TEST] FEC response code received mismatches. Actual: %0d Expected: 0", $time, rsp_code);
      result = 1;
    end
    
   `WAIT_CLK(clk, 20)
    $display("[%0t][TB-TEST] TEST %s", $time, result?"FAILED":"PASSED"); 
    $display("");
             
  endtask
  
  
  // FEC Transmission Boundary payloads ====================================================
  
  
  task test_fec_data_tx_boundary_payloads();
    $display("[%0t][TB-TEST] ======= Bounday payloads =======", $time);    
    test_fec_data_tx(7);
    test_fec_data_tx(8);
  endtask
  
  
  // FEC data Transmission with invalid payloads
  
  
  task test_fec_data_tx_invalid_payloads();
    static bit [3:0] msg_tag = $urandom_range(0, 15);
    bit [7:0] rsp_cmd, rsp_tag, rsp_code;
    bit [7:0] err_resp, err_code;
    bit result;
    
    $display("[%0t][TB-TEST] ==== Invalid payloads error ====", $time);
    $display("[%0t][TB-TEST] ====    No payload 0          ==", $time);
    
    //fec_data_transmit_rand(0);
    fec_data_transmit_rand(0, msg_tag, rsp_cmd, rsp_tag, rsp_code);
    uart_receive_8b(err_resp[7:0]); // Err response command
    uart_receive_8b(err_code[7:0]); // Command result (Error code)
    
    // check for error response
    if(err_resp==CMD_ERR_RS)
      $display("[%0t][TB-TEST] FEC Error response command ID received is as expeted: %0d.", $time, CMD_ERR_RS);
    else begin
      $error("[%0t][TB-TEST] FEC Error response command ID received mismatches. Actual: %0d Expected: %0d", $time, err_resp, CMD_ERR_RS);
      result = 1;
    end
    // Check for error code
    if(err_code==8'b1000)
      $display("[%0t][TB-TEST] FEC Error response code received is as expeted: 8.", $time);
    else begin
      $error("[%0t][TB-TEST] FEC Error response code received mismatches. Actual: %0d Expected: 0", $time, err_code);
      result = 1;
    end
    `WAIT_CLK(clk, 20)
    
    
    $display("[%0t][TB-TEST] ====    Payload overflow      ==", $time);
    msg_tag = $urandom_range(0, 15);
    //fec_data_transmit_rand(256);
    fec_data_transmit_rand(256, msg_tag, rsp_cmd, rsp_tag, rsp_code);
    uart_receive_8b(err_resp[7:0]); // Err response command
    uart_receive_8b(err_code[7:0]); // Command result (Error code)
    
    // check for error response
    if(err_resp==CMD_ERR_RS)
      $display("[%0t][TB-TEST] FEC Error response command ID received is as expeted: %0d.", $time, CMD_ERR_RS);
    else begin
      $error("[%0t][TB-TEST] FEC Error response command ID received mismatches. Actual: %0d Expected: %0d", $time, err_resp, CMD_ERR_RS);
      result = 1;
    end
    // Check for error code
    if(err_code==8'b1000)
      $display("[%0t][TB-TEST] FEC Error response code received is as expeted: 8.", $time);
    else begin
      $error("[%0t][TB-TEST] FEC Error response code received mismatches. Actual: %0d Expected: 0", $time, err_code);
      result = 1;
    end
    
    `WAIT_CLK(clk, 20)
    $display("[%0t][TB-TEST] TEST %s", $time, result?"FAILED":"PASSED"); 
    $display("");
  endtask
  
  
  // ========================================================
  //                   FEC Module Drivers
  // ========================================================
  
  
  // FEC Command error =====================================================================
  
  
  task fec_command_error(command_t command, output logic[7:0] err_resp, output logic[7:0] err_code);    
    $display("[%0t][TB-TASK] FEC Command error ID: %0d", $time, command);
    
    uart_send_8b(command);            // 1: Command (Shall be undefined)
    uart_receive_8b(err_resp[7:0]); // Err response command
    uart_receive_8b(err_code[7:0]); // Command result (Error code)
    
  endtask
  
  
  // FEC Data transmit random with timeout error ===========================================
  
  
  task fec_data_transmit_rand_with_timeout_error(bit[7:0] msg_len, uart_error_t uart_error,int baudrate=uart_br);
    static bit [3:0] msg_tag = $urandom_range(0,15);
    int timeout_clk_cyles;
    int ps, clks_per_bit, rto_data_bit, timeout_clk_cycles;
    logic [5:0] uart_cfg_timeout_bits;
    
    //ps = `SYS_CLK_FREQ / (baudrate * UART_SC)-1;
    ps                    = `SYS_CLK_FREQ / (baudrate * UART_SC);
    clks_per_bit          = UART_SC * ps;
    uart_cfg_timeout_bits = fec_u.uart_timeout_bits;
    timeout_clk_cycles    = clks_per_bit * (uart_cfg_timeout_bits);
    
    
    $display("[%0t][TB-TASK] FEC Data transmit with timeout error start. Message length: %0d, Tag: %0d Timeout on %s Clk cyles: %0d", $time, msg_len, msg_tag, uart_error.name(), timeout_clk_cycles);
    
    uart_send_8b(CMD_FEC_TX);// 1: Command     : 2: transmit
    if(uart_error==UART_RX_RTO_COMMAND) begin repeat(timeout_clk_cyles) @(posedge clk); return; end
    
    uart_send_8b(msg_len);   // 2: Message lenght : msg_len
    if(uart_error==UART_RX_RTO_MSG_LENGHT) begin repeat(timeout_clk_cyles) @(posedge clk); return; end
    
    if(msg_len==0) return;
    uart_send_8b(msg_tag);   // 3: Message Tag
    if(uart_error==UART_RX_RTO_MSG_TAG) begin repeat(timeout_clk_cyles) @(posedge clk); return; end
    
    repeat(msg_len) begin             // 4: Message        : Rand data
      uart_send_8b($urandom_range(0,255));
      if(uart_error==UART_RX_RTO_DATA) begin repeat(timeout_clk_cyles) @(posedge clk); return; end
    end
    $display("[%0t][TB-TASK] FEC Data transmit end. Tag: %0d", $time, msg_tag);
  endtask
  
  
  // FEC Data transmit random with delay ====================================================
  
  
  task fec_data_transmit_rand_with_delay(bit[7:0] msg_len, int baudrate=uart_br);
    static bit [3:0] msg_tag = $urandom_range(0,15);
    $display("[%0t][TB-TASK] FEC Data transmit start with delay. Message length: %0d, Tag: %0d", $time, msg_len, msg_tag);
    
    uart_send_8b(CMD_FEC_TX);// 1: Command     : 2: transmit
    uart_send_8b(msg_len);   // 2: Message lenght : msg_len
    
    if(msg_len==0) return;
    uart_send_8b(msg_tag);   // 3: Message Tag
    repeat(msg_len) begin             // 4: Message        : Rand data
      uart_send_8b($urandom_range(0,255));
    end
    $display("[%0t][TB-TASK] FEC Data transmit end. Tag: %0d", $time, msg_tag);
  endtask
  
  
  // FEC Data transmit UART response =======================================================
  
  
  task fec_data_transmit_uart_response(output bit[7:0] rsp_cmd, output bit[7:0] rsp_tag, output bit[7:0] rsp_code);
    uart_receive_8b(rsp_cmd);
    uart_receive_8b(rsp_tag);
    uart_receive_8b(rsp_code);
    $display("[%0t][TB-TASK] FEC Data transmit UART response end.", $time);
  endtask
  
  
  // FEC Data transmit Downlink stream =====================================================
  
  
  task fec_data_transmit_dl_stream(bit[7:0] msg_len);
    //static bit [6:0] dl_en_cnt;
    //dl_en_cnt = $ceil(real'(msg_len)/7.0) + 1;
    //$display("[%0t][TB-TASK] FEC Data transmit Downlink stream start. DL negedges to wait: %0d", $time, dl_en_cnt);
    //repeat(dl_en_cnt) @(negedge dl_en);
    //$display("[%0t][TB-TASK] FEC Data transmit Downlink stream end. DL negedges cnt %0d", $time, dl_en_cnt);
    @(negedge dl_en);
    $display("[%0t][TB-TASK] FEC Data transmit Downlink stream end.", $time);
  endtask
  
  
  // FEC Data transmit random data =========================================================
  
  
  task fec_data_transmit_rand(bit[7:0] msg_len, bit [3:0] msg_tag, output bit[7:0] rsp_cmd, output bit[7:0] rsp_tag, output bit[7:0] rsp_code, input int baudrate=uart_br);
    //bit [3:0] msg_tag = $urandom_range(0,15);
    $display("[%0t][TB-TASK] FEC Data transmit start. Message length: %0d, Tag: %0d", $time, msg_len, msg_tag);
    
    uart_send_8b(CMD_FEC_TX);// 1: Command        : 2: transmit
    uart_send_8b(msg_len);   // 2: Message lenght : msg_len
    if(msg_len==0) return;
    uart_send_8b(msg_tag);   // 3: Message Tag
    repeat(msg_len) begin    // 4: Message        : Random data
      uart_send_8b($urandom_range(0,255));
    end
    fork
      fec_data_transmit_uart_response(rsp_cmd, rsp_tag, rsp_code);
      fec_data_transmit_dl_stream(msg_len);
    join
    
    $display("[%0t][TB-TASK] FEC Data transmit end. Tag: %0d", $time, msg_tag);
  endtask
  
  
  // FEC Register read =====================================================================
  
  
  task fec_reg_read(reg_addr_t reg_addr, output bit [31:0] reg_data, input bit acc=1);
    $display("[%0t][TB-TASK] FEC Register read start. Register: %s, Addr: 0x%0h Access: %s", $time, reg_addr.name(), reg_addr, acc?"physical":"virtual");
    
    // Physical access
    if(acc) begin
      uart_send_8b(CMD_REG_READ);       // 1: Command:  Reg read
      uart_send_8b(reg_addr);           // 2: Register offset
      uart_receive_8b(reg_data[31:24]); // Register data - MSB
      uart_receive_8b(reg_data[23:16]);
      uart_receive_8b(reg_data[15: 8]);
      uart_receive_8b(reg_data[ 7: 0]); // LSB
    end
    
    // Virtual access
    else begin
      @(posedge clk);
      force fec_u.reg_cfg_u.pwrite  = 1'b0;
      force fec_u.reg_cfg_u.penable = 1'b1;
      force fec_u.reg_cfg_u.psel    = 1'b1;
      force fec_u.reg_cfg_u.paddr   = reg_addr;
      @(negedge clk);
      reg_data                      = fec_u.reg_cfg_u.prdata;
      //$display("[%0t][TB-TASK] Read data 0x%0h", $time, reg_data);
      @(posedge clk);
      release fec_u.reg_cfg_u.pwrite;
      release fec_u.reg_cfg_u.penable;
      release fec_u.reg_cfg_u.psel;
      release fec_u.reg_cfg_u.paddr;
    end
  endtask
  
  
  // FEC Register write =====================================================================
  
  
  task fec_reg_write(reg_addr_t reg_addr, bit[31:0] reg_data, output bit[7:0] rsp_cmd, output bit[7:0] rsp_addr, output bit[7:0] rsp_code,  input bit acc=1, input bit check=0); 
    bit[31:0] rdata;
    //bit[7:0] rsp_cmd, rsp_addr, rsp_code;
    
    $display("[%0t][TB-TASK] FEC Register write start. Register: %s, Addr: 0x%0h WData: 0x%0h Access: %s", $time, reg_addr.name(), reg_addr, reg_data, acc?"physical":"virtual");
    
    // Physical access
    if(acc) begin 
      uart_send_8b(CMD_REG_WRITE);    // 1: Command:  Reg write
      uart_send_8b(reg_addr);         // 2: Register offset
      uart_send_8b(reg_data[31:24]);  // 3: Config data - MSB
      uart_send_8b(reg_data[23:16]);
      uart_send_8b(reg_data[15: 8]);
      uart_send_8b(reg_data[ 7: 0]);  // LSB
      repeat(5) @(posedge clk);
      uart_receive_8b(rsp_cmd); // Register data - MSB
      uart_receive_8b(rsp_addr);
      uart_receive_8b(rsp_code);
      
    end
    
    // Virtual acces
    else begin
      @(negedge clk);
      force fec_u.reg_cfg_u.pwrite  = 1'b1;
      force fec_u.reg_cfg_u.penable = 1'b1;
      force fec_u.reg_cfg_u.psel    = 1'b1;
      force fec_u.reg_cfg_u.paddr   = reg_addr;
      force fec_u.reg_cfg_u.pwdata  = reg_data;
      @(negedge clk);
      release fec_u.reg_cfg_u.pwrite;
      release fec_u.reg_cfg_u.penable;
      release fec_u.reg_cfg_u.psel;
      release fec_u.reg_cfg_u.paddr;
      release fec_u.reg_cfg_u.pwdata;
    end
    
    // Read written data with virtual access
    if(check) begin
      fec_reg_read(reg_addr, rdata, 0);
    
      // Check for data integrity
      if((reg_data!=rdata))
        $error("[%0t][TB-TASK] Register write failed. Written data: 0x%0h Read: 0x%0h", $time, reg_data, rdata);
    end
  endtask
  
  
  // ========================================================
  //                     UART Drivers
  // ========================================================
  
  
  // UART Receive 8b ========================================================================
  
  
  task uart_receive_8b(output bit[7:0] data /*, input int baudrate=uart_br*/);
    bit [15:0] pr;
    int clks_per_bit;           // clock cycles per uart bit
    int clks_to_mid_bit;        // clock cycles to middle of a uart bit
    bit parity_bit, parity_err, stop_bit;
    
    //ps = `SYS_CLK_FREQ / (baudrate * UART_SC);
    pr              = fec_u.uart_prescaler;
    clks_per_bit    = UART_SC * (pr+1);
    clks_to_mid_bit = clks_per_bit/2;
    
    //$display("[%0t][TB-TASK] UART TX monitor", $time);
    //$display("[%0t][TB-TASK] UART TX prescaler  : %0d", $time, pr);
    //$display("[%0t][TB-TASK] UART TX Clks/Bit: %0d", $time, clks_per_bit);
    //$display("[%0t][TB-TASK] UART TX Midpoint: %0d", $time, clks_to_mid_bit);
    
    // 1. Start bit
    while (uart_tx == 1) @(posedge clk);
    //$display("[%0t][TB-TASK] Detected Start Bit", $time);
    
    // Wait to middle of bit
    repeat (clks_to_mid_bit) @(posedge clk);
    if (uart_tx == 1) begin
        $error("[%0t][TB-TASK] RX Sync Error: Start bit was HIGH at midpoint.", $time);
    end
    
    // 2. Data bits (8 bits)
    for(int ii=0; ii<8; ii++) begin
        repeat (clks_per_bit) @(posedge clk);
        data[ii] = uart_tx;
    end
    
    // 3. Parity bit (Optional)
    if(UART_PARITY_TYPE != 0) begin
        repeat (clks_per_bit) @(posedge clk);
        parity_bit = uart_tx;
      //$display("[%0t][TB-TASK] Sampled Parity Bit: %0b", $time, parity_bit);
      case(UART_PARITY_TYPE)
        1: if(parity_bit != ~(^data)) parity_err = 1;// Odd
        2: if(parity_bit !=  (^data)) parity_err = 1;// Even
        3: if(parity_bit !=  1'b0)    parity_err = 1;// Sticky 0
        4: if(parity_bit !=  1'b1)    parity_err = 1;// Sticky 1
      endcase
      if (parity_err) begin
        $error("[%0t][TB-TASK] UART-TX Parity Error. Expected: %0d  Received: %0d.", $time, ~parity_bit, parity_bit);
      end
    end
        
    // 4. Stop Bit
    repeat (clks_per_bit) @(posedge clk);
    stop_bit = uart_tx;
    if (stop_bit == 0) begin
      $error("[%0t][TB-TASK] UART-TX Framing Error. Received stop bit is LOW at midpoint.", $time);
    end
    
    //$display("[%0t][TB-TASK] Finished RX monitor. Data received: 0x%0h", $time, data);
    
  endtask
  
  
  // UART Send 8b ==========================================================================
  
  
  task uart_send_8b(bit[7:0] data /*, int baudrate=uart_br*/);
    int clks_per_bit;
    bit [15:0] pr;
    
    //ps           = `SYS_CLK_FREQ / (baudrate * UART_SC);
    pr           = fec_u.uart_prescaler;
    clks_per_bit = UART_SC * (pr+1);
    
    //$display("[%0t][TB-TASK] UART data      : 0x%0h ", $time, data);
    //$display("[%0t][TB-TASK] UART prescaler : %0d   ", $time, pr);
    //$display("[%0t][TB-TASK] UART clks/bit  : %0d   ", $time, clks_per_bit);
    
    //@(negedge clk);
    
    // 1. Sart bit
    uart_rx = 0;
    //$display("[%0t][TB-TASK] UART start bit %0b    ", $time, uart_rx);
    repeat(clks_per_bit) @(posedge clk);
        
    // 2. Data bits (8 bits)
    for(int ii=0; ii<UART_SC; ii++)begin
      uart_rx = data[ii];
      //$display("[%0t][TB-TASK] UART data bit %0d:%0b    ", $time, ii, uart_rx);
      repeat(clks_per_bit) @(posedge clk);
    end
    
    // 3. Parity bit (Optional)
    if(UART_PARITY_TYPE != 0) begin
      case(UART_PARITY_TYPE)
        1: uart_rx = ~(^data);// Odd
        2: uart_rx =  (^data);// Even
        3: uart_rx = 1'b0;    // Sticky 0
        4: uart_rx = 1'b1;    // Sticky 1
        default: $fatal("Unsuported parity bit");
      endcase
      // $display("[%0t][TB-TASK] UART parity bit %0b", $time, uart_rx);
      repeat(clks_per_bit) @(posedge clk);
    end
    
    // 4. End bit(s) high
    uart_rx = 1;
    //$display("[%0t][TB-TASK] UART end bit %0b", $time, uart_rx);
    repeat(clks_per_bit) @(posedge clk);
    
    // Exit task with TX set high
    //$display("[%0t][TB-TASK] UART send 8b finished", $time);
    uart_rx = 1;
    
  endtask
  
  
  // UART Send 8b with error ===============================================================
  
  
  task uart_send_with_error(uart_error_t uart_error, bit[7:0] data, int baudrate=uart_br);
    int ps, clks_per_bit, rto_data_bit, timeout_clk_cycles;
    logic [5:0] uart_cfg_timeout_bits;
    
    ps                    = `SYS_CLK_FREQ / (baudrate * UART_SC);
    clks_per_bit          = UART_SC * ps;
    uart_cfg_timeout_bits = fec_u.uart_timeout_bits;
    timeout_clk_cycles    = clks_per_bit * (uart_cfg_timeout_bits+1);
    
    $display("[%0t][TB-TASK] UART TX Error    : %s ", $time, uart_error.name());
    //$display("[%0t][TB-TASK] UART data      : 0x%0h ", $time, data);
    //$display("[%0t][TB-TASK] UART prescaler : %0d   ", $time, ps);
    //$display("[%0t][TB-TASK] UART clks/bit  : %0d   ", $time, clks_per_bit);
    //$display("[%0t][TB-TASK] UART TO Bits   : %0d   ", $time, uart_cfg_timeout_bits);
    //$display("[%0t][TB-TASK] UART TO Clocks : %0d   ", $time, timeout_clk_cycles);
    
    // 1. Sart bit
    uart_rx = 0;
    //$display("[%0t][TB-TASK] UART start bit %0b    ", $time, uart_rx);
    repeat(clks_per_bit) @(posedge clk);
        
    // 2. Data bits (8 bits) with or without error
    if(uart_error==UART_RX_RTO_DATA_BITS) begin
      rto_data_bit = $urandom_range(0,6);
      $display("[%0t][TB-TASK] UART-RX Timeout to be provoked on data bit %0d", $time, rto_data_bit);
    end
    
    for(int ii=0; ii<UART_SC; ii++)begin
      uart_rx = data[ii];
      //$display("[%0t][TB-TASK] UART data bit %0d:%0b    ", $time, ii, uart_rx);
      
      if(uart_error==UART_RX_RTO_DATA_BITS) begin
        if(rto_data_bit==ii) begin
          $display("[%0t][TB-TASK] Wait TO clk cycles", $time);
          repeat(timeout_clk_cycles) @(posedge clk); // Wait TO bits + 1 to provoke TO error
          $display("[%0t][TB-TASK] Wait TO clk cycles DONE", $time);
          uart_rx = 1;
          return;
        end
        else
          repeat(clks_per_bit) @(posedge clk); // Wait as normal
      end
      else
          repeat(clks_per_bit) @(posedge clk); // Wait as normal
    end
    
    // 3. Parity bit (Optional)
    if(UART_PARITY_TYPE != 0) begin
      case(UART_PARITY_TYPE)
        1: uart_rx = ~(^data);// Odd
        2: uart_rx =  (^data);// Even
        3: uart_rx = 1'b0;    // Sticky 0
        4: uart_rx = 1'b1;    // Sticky 1
        default: $fatal("Unsuported parity bit");
      endcase
      //$display("[%0t][TB-TASK] UART parity bit %0b    ", $time, uart_rx);
      repeat(clks_per_bit) @(posedge clk);
    end
    
    // 4. End bit(s) with ot without error
    if(uart_error==UART_RX_FER) begin
      $display("[%0t][TB-TASK] UART-RX Frame error to be provoked", $time);
      clks_per_bit = int'(real'(clks_per_bit)*0.65);
      uart_rx = 0; // Set bit to 0 to provoke a frame error
      repeat(clks_per_bit) @(posedge clk);
    end
    else begin
      uart_rx = 1; // Set bit to 1 as normal
      //$display("[%0t][TB-TASK] UART end bit %0b    ", $time, uart_rx);
      repeat(clks_per_bit) @(posedge clk);
    end
    // Exit task with TX set high
    uart_rx = 1;
    
  endtask
  
  
  // UART Setup baudrate ===================================================================
  
  
  task uart_setup_baudrate(int baudrate, bit acc=1);
    bit[31:0] wdata;
    bit[15:0] prescaler ;
    bit [7:0] rsp_cmd, rsp_addr, rsp_code;
    //int prescaler = `SYS_CLK_FREQ/(115200*UART_SC ) - 1; // This didn't work, need to caclulate separatedly
    
    prescaler = `SYS_CLK_FREQ / (baudrate * UART_SC)-1;
    $display("[%0t][TB-TASK] UART setup baudrate: %0d, prescaler: %0d", $time, baudrate, prescaler);
    
    wdata[15:0] = prescaler;
    fec_reg_write(REG_ADDR_UART_PR, wdata, rsp_cmd, rsp_addr, rsp_code, acc, 1);
    
    // Update global var
    uart_br = baudrate;
    
  endtask
  
  
  // UART general setup ===================================================================
  
  
  task uart_setup();
    //force fec_u.uart_en               = 1;// UART reset values
    //force fec_u.uart_tx_en            = 1;
    //force fec_u.uart_rx_en            = 1;
    //force fec_u.uart_rd               = 0;
    //force fec_u.uart_wr               = 0;
    //Sforce fec_u.uart_wdata            = 0;
    //force fec_u.uart_prescaler        = uart_ps;
    //force fec_u.uart_data_size        = 8;
    //force fec_u.uart_stop_bits_count  = 0;
    //force fec_u.uart_parity_type      = UART_PARITY_TYPE;
    //
    //force fec_u.uart_timeout_bits     = 6'd63; // Already in initial value
    //force fec_u.uart_loopback_en      = 0; // Already in initial value
    //force fec_u.uart_glitch_filter_en = 0; // Already in initial value
  endtask;
  
    
  task dl_ctrl_setup();
    force fec_u.dl_ctrl_clk_div  = ser_clk_div;
  endtask
  
  
  
  // Downlink monitor =====================================================================
  
  
  task downlink_monitor();
    
    typedef enum bit[2:0] {
      S_IDLE = 0,
      S_TRAINING,
      S_SYNC_1,
      S_DATA_SAMPLE,
      S_MESSAGE
    } dl_mon_st_t;
    
    dl_mon_st_t dl_mon_st;
    
    bit [$clog2(SERIAL_DATA_DEPTH):0] dl_preamble_cnt;
    bit [SERIAL_DIV_WIDTH-1:0] ser_clk_cnt;
    bit [SERIAL_DIV_WIDTH-1:0] trained_ser_clk;
    bit [SERIAL_DIV_WIDTH-1:0] sync_cnt;
    bit dl_out_pre;
    bit        sampled_data_dec;
    bit [ 7:0] sampled_idx;
    bit [23:0] sampled_data_1;
    bit [79:0] sampled_data_0;
    
    $display("[%0t][TB-DL-MON] downlink_monitor started", $time);
    
    fork 
      begin // Downlink Monitor
        
        forever begin
          
          // Wait for dl_en is high
          @(posedge clk iff(dl_en=='b1));
          
          case(dl_mon_st)
            
            S_IDLE: begin
              //$display("[%0t][TB-DL-MON] S_IDLE", $time);
              dl_out_pre      = 0;
              trained_ser_clk = 0;
              ser_clk_cnt     = 0;
              
              //@(posedge clk);
              if(dl_out == 1'b1) begin
                dl_mon_st       = S_TRAINING;
                ser_clk_cnt     = 1;
                dl_preamble_cnt = 0;
                dl_out_pre      = 0;
                //$display("[%0t][TB-DL-MON] 1st posedge detected %0d", $time, dl_preamble_cnt);
              end
            end
            
            S_TRAINING: begin
                            
              // Count when dl_out is high
              if(dl_out == 1'b1) ser_clk_cnt++;
              
              // If posedge 
              if(dl_out=='b1 && dl_out_pre=='b0) begin
                dl_out_pre = 'b1;
                //$display("[%0t] [DL-MON] Posedge detected %0d", $time, dl_preamble_cnt);
              end
                
              // If negative edge -> increase dl preamble count 
              if(dl_out=='b0 && dl_out_pre=='b1) begin
                dl_out_pre = 0;
                dl_preamble_cnt++;
                //$display("[%0t] [DL-MON] Negedge detected %0d", $time, dl_preamble_cnt);
                  
                // Check if preamble count is acheived
                if(dl_preamble_cnt == DL_PREAMBLE_COUNT) begin
                  trained_ser_clk = ser_clk_cnt>>($clog2(DL_PREAMBLE_COUNT));
                  ser_clk_cnt     = 0;
                  sampled_data_dec = 1;
                  sampled_idx      = 0;
                  //dl_mon_st       = S_SYNC_1;
                  dl_mon_st       = S_DATA_SAMPLE;
                  $display("[%0t][DL-MON] Trained serial clock %0d", $time, trained_ser_clk);
                end
                  
              end  
              
            end // S_TRAINING
            
            S_SYNC_1: begin
              sync_cnt++;
              if(sync_cnt == trained_ser_clk>>1) begin
                dl_mon_st = S_DATA_SAMPLE;
                //$display("[%0t] [DL-MON] Sync 1 done $0d", $time, sync_cnt);
                sync_cnt = 0;
              end
            end
            
            S_DATA_SAMPLE: begin
              
              sync_cnt++;
              if(sync_cnt == trained_ser_clk) begin
                if(sampled_data_dec) begin
                  sampled_data_1[sampled_idx] = dl_out;
                end
                else begin
                  sampled_data_0[sampled_idx] = dl_out;
                end
                
                sync_cnt =0;
                sampled_idx++;
                if(sampled_idx == 24)
                    dl_mon_st = S_IDLE;
              
              end
              
            end
            
            default:
              $error("[%0t][TB-DL-MON] Undefined state", $time);
          
          endcase
          
        end // forever
        
      end // Downlink Monitor
      
      begin // Hang detector

      // Hang detector code here

      end
    join_none
    
  endtask
  
  endmodule


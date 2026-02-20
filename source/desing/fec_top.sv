//`timescale        1ns/1ps
//`default_nettype  none // Commented line to prevent Questasim error: (vlog-2892) Net type of 'clk' was not explicitly declared.

`include "defines.svh"

module fec_top(
  // System
  input  logic  clk,
  input  logic  rst_n,
  // UART
  input  logic  uart_rx,
  output logic  uart_tx,
   // Downlink
  output logic  dl_ready,
  output logic  dl_out,
  output logic  dl_en,
  // Uplink
  input  logic  ul_in,
  input  logic  ul_en
  );
  
  // APB Register Config
  logic                      apb_psel;
  logic                      apb_penable;
  logic                      apb_pwrite;
  logic [APB_ADDR_WIDTH-1:0] apb_paddr;
  logic [APB_DATA_WIDTH-1:0] apb_pwdata;
  logic [APB_DATA_WIDTH-1:0] apb_prdata;
  logic                      apb_pslverr;
  
  // FEC FSM Control
  logic                dl_fec_crc0_start;
  logic                dl_fec_crc1_start;
  logic                dl_fec_enc0_done;
  logic                dl_fec_enc1_done;
  logic                dl_ctrl_start;
  logic                dl_ctrl_done;
  logic [1:0]          dl_ctrl_enc_used;
  logic                uart_tx_flush_fsm;
  logic                uart_rx_flush_fsm;
    
  // UART
  logic                uart_en;
  logic                uart_tx_en;
  logic                uart_rx_en;
  logic                uart_rd; 
  logic                uart_wr;
  logic [UART_MDW-1:0] uart_wdata;
  logic [UART_MDW-1:0] uart_rdata;
  logic [15:0]         uart_prescaler;
  logic [3:0]          uart_data_size;
  logic                uart_stop_bits_count;
  logic [2:0]          uart_parity_type;
  logic [5:0]          uart_timeout_bits;
  logic                uart_loopback_en;
  logic                uart_glitch_filter_en;
  logic                uart_rx_fifo_reg;
  logic                uart_tx_empty;
  logic                uart_tx_full;
  logic                uart_tx_done;  
  logic [2**UART_TX_FAW-1:0][UART_MDW-1:0] uart_tx_array_reg;
  logic [UART_TX_FAW-1:0] uart_tx_level;
  logic                uart_tx_level_below;
  logic                uart_tx_flush;
  logic                uart_rx_empty;
  logic                uart_rx_full;
  logic                uart_rx_done;
  logic [2**UART_RX_FAW-1:0][UART_MDW-1:0] uart_rx_array_reg;
  logic [UART_RX_FAW-1:0] uart_rx_level;
  logic                uart_rx_level_above;
  logic                uart_rx_flush;
  logic [1:0]          uart_tx_grant;
  logic [1:0]          uart_tx_req;
  logic                uart_break_flag;
  logic                uart_match_flag;
  logic                uart_frame_error_flag;
  logic                uart_parity_error_flag;
  logic                uart_overrun_flag;
  logic                uart_timeout_flag;
  logic [1:0]          uart_fatal_errors;
  
  // Downlink FEC signals
  logic [2**UART_RX_FAW-1:0][UART_MDW-1:0] dl_fec_data_out;
  logic [7:0]                  dl_msg_len;
  logic [3:0]                  dl_fec_msg_tag;  
  logic [ENC0_DATA_DEPTH-1:0]  dl_fec_enc0_row_p;
  logic [ENC0_DATA_WIDTH-1:0]  dl_fec_enc0_col_p;
  logic [ENC1_DATA_DEPTH-1:0]  dl_fec_enc1_row_p;
  logic [ENC1_DATA_WIDTH-1:0]  dl_fec_enc1_col_p;
  logic [CRC0_WIDTH-1:0]       dl_fec_crc0_data;
  logic [CRC1_WIDTH-1:0]       dl_fec_crc1_data;
  logic [SERIAL_DIV_WIDTH-1:0] dl_ctrl_clk_div;
  
  logic                        dl_uart_tx_wr;
  logic [UART_MDW-1:0]         dl_uart_tx_wdata;  
  logic                        dl_uart_tx_grant;
  logic                        dl_uart_tx_req;

  // Uplink FEC signals
  logic                        ul_uart_tx_wr;
  logic [UART_MDW-1:0]         ul_uart_tx_wdata;
  logic                        ul_uart_tx_grant;
  logic                        ul_uart_tx_req;
  
  assign dl_uart_tx_grant  =  uart_tx_grant[0];
  assign ul_uart_tx_grant  =  uart_tx_grant[1];
  assign uart_fatal_errors = {uart_frame_error_flag, uart_timeout_flag};
  
 
  // ======  Register configuration (with AMBA APB)  ======= 
  logic [15:0] uart_prescaler_reg;
  logic [04:0] uart_ctrl_reg;
  logic [13:0] uart_cfg_reg;
  logic [31:0] dl_err_inj_mask_0;
  logic [31:0] dl_err_inj_mask_1;
  logic dl_err_inj_enable, dl_err_inj_enable_clear;
  reg_cfg #(
    .ADDR_WIDTH             (APB_ADDR_WIDTH),
    .DATA_WIDTH             (APB_DATA_WIDTH)
  ) reg_cfg_u (
    .pclk                   (clk),
    .presetn                (rst_n),
    .psel                   (apb_psel),
    .penable                (apb_penable),
    .pwrite                 (apb_pwrite),
    .paddr                  (apb_paddr),
    .pwdata                 (apb_pwdata),
    .prdata                 (apb_prdata),
    .pslverr                (apb_pslverr),
    .DL_SER_CLK_DIV         (dl_ctrl_clk_div),
    .DL_ERR_INJ_MASK_0      (dl_err_inj_mask_0),
    .DL_ERR_INJ_MASK_1      (dl_err_inj_mask_1),
    .DL_ERR_INJ_ENABLE      (dl_err_inj_enable),
    .DL_ERR_INJ_ENABLE_CLEAR(dl_err_inj_enable_clear),
    .UART_PR                (uart_prescaler_reg),
    .UART_CTRL              (uart_ctrl_reg),
    .UART_CFG               (uart_cfg_reg)
  );
  
  // ===========   UART   ===========
  assign uart_prescaler         = uart_prescaler_reg[15:0];
  assign uart_glitch_filter_en  = uart_ctrl_reg[4];
  assign uart_loopback_en       = uart_ctrl_reg[3];
  assign uart_rx_en             = uart_ctrl_reg[2];
  assign uart_tx_en             = uart_ctrl_reg[1];
  assign uart_en                = uart_ctrl_reg[0];
  assign uart_timeout_bits      = uart_cfg_reg[13:8];
  assign uart_parity_type       = uart_cfg_reg[7:5];
  assign uart_stop_bits_count   = uart_cfg_reg[4];
  assign uart_data_size         = uart_cfg_reg[3:0]; 
  //assign uart_rx_flush          = uart_rx_flush_reg[0] | uart_rx_flush_fsm;
  assign uart_rx_flush          = uart_rx_flush_fsm;
  //assign uart_tx_flush          = uart_tx_flush_reg[0] | uart_tx_flush_fsm;
  //assign uart_tx_flush          = uart_tx_flush_fsm;
  assign uart_tx_flush          = 1'b0;
  assign uart_rd                = 1'b0;
  assign uart_wr                = 1'b0;
  assign uart_tx_req            = {ul_uart_tx_req, dl_uart_tx_req};
  
  EF_UART #(
    .MDW              (UART_MDW), 
    .TX_FAW           (UART_TX_FAW),
    .RX_FAW           (UART_RX_FAW),
    .SC               (UART_SC),
    .GFLEN            (UART_GFLEN)
    ) uart_u (
    .clk              (clk),
    .rst_n            (rst_n),
    .prescaler        (uart_prescaler),
    .en               (uart_en),
    .tx_en            (uart_tx_en),
    .rx_en            (uart_rx_en),
    .rd               (uart_rd),
    
    .wr0              (dl_uart_tx_wr),  // DL FEC FSM
    .wdata0           (dl_uart_tx_wdata),
    .wr1              (ul_uart_tx_wr),  // UL FEC FSM
    .wdata1           (ul_uart_tx_wdata),
    .req              (uart_tx_req),
    .grant            (uart_tx_grant),
    
    .rdata            (uart_rdata),
    .data_size        (uart_data_size),
    .stop_bits_count  (uart_stop_bits_count),
    .parity_type      (uart_parity_type),
    .txfifotr         (4'h0),
    .rxfifotr         (4'h0),
    .match_data       (8'h0),
    .timeout_bits     (uart_timeout_bits),
    .loopback_en      (uart_loopback_en),
    .glitch_filter_en (uart_glitch_filter_en),
    
    .tx_empty         (uart_tx_empty),
    .tx_full          (uart_tx_full),
    .tx_level         (uart_tx_level),
    .tx_level_below   (uart_tx_level_below),
    .tx_done          (uart_tx_done),
    .tx_array_reg     (uart_tx_array_reg),
    .tx_fifo_flush    (uart_tx_flush),
      
    .rx_empty         (uart_rx_empty),
    .rx_full          (uart_rx_full),
    .rx_level         (uart_rx_level),
    .rx_level_above   (uart_rx_level_above),
    .rx_done          (uart_rx_done),
    .rx_array_reg     (uart_rx_array_reg),
    .rx_fifo_flush    (uart_rx_flush),
      
    .break_flag       (uart_break_flag),
    .match_flag       (uart_match_flag),
    .frame_error_flag (uart_frame_error_flag),
    .parity_error_flag(uart_parity_error_flag),
    .overrun_flag     (uart_overrun_flag),
    .timeout_flag     (uart_timeout_flag),
    .rx               (uart_rx),
    .tx               (uart_tx)
  );
  
  logic [2**UART_RX_FAW-1:0][UART_MDW-1:0] uart_rx_array_r ;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n)
      uart_rx_array_r <= 'h0;
    else
      if(uart_rx_fifo_reg) begin
        uart_rx_array_r <= uart_rx_array_reg;
        //$display("[%0t] uart_rx_array_reg registered", $time);
      end
      else
        uart_rx_array_r <= uart_rx_array_r;
  end
  
  // =========================================================
  // =                 Downlink data path                    =
  // =========================================================

  // ====== DL FEC Control FSM  =======
  
  dl_fec_fsm dl_fec_fsm_u (
    .clk                    (clk),
    .rst_n                  (rst_n),
    .ready                  (dl_ready),
    // UART Control
    .uart_rx_array          (uart_rx_array_reg),
    .uart_rx_done           (uart_rx_done),
    .uart_rx_level          (uart_rx_level),
    .uart_rx_fifo_flush     (uart_rx_flush_fsm),
    .uart_rx_fifo_reg       (uart_rx_fifo_reg),
    .uart_tx_level          (uart_tx_level),
    .uart_fatal_errors      (uart_fatal_errors),
    // Downlink control
    .dl_uart_tx_wr          (dl_uart_tx_wr),
    .dl_uart_tx_wdata       (dl_uart_tx_wdata),
    .dl_uart_tx_grant       (dl_uart_tx_grant),
    .dl_uart_tx_req         (dl_uart_tx_req),
    .dl_fec_msg_tag         (dl_fec_msg_tag),
    .dl_fec_msg_len         (dl_msg_len),
    .dl_fec_crc0_start      (dl_fec_crc0_start),
    .dl_fec_enc0_done       (dl_fec_enc0_done),
    .dl_fec_crc1_start      (dl_fec_crc1_start),
    .dl_fec_enc1_done       (dl_fec_enc1_done),
    .dl_ctrl_enc_used       (dl_ctrl_enc_used),
    .dl_ctrl_start          (dl_ctrl_start),
    .dl_ctrl_ser_en         (dl_en),
    // Register Access
    .psel                   (apb_psel),
    .penable                (apb_penable),
    .pwrite                 (apb_pwrite),
    .paddr                  (apb_paddr),
    .pwdata                 (apb_pwdata),
    .prdata                 (apb_prdata),
    .pslverr                (apb_pslverr)
  );

  // ========= DL FEC Engine =========
  
  dl_fec_engine dl_fec_u (
    .clk                  (clk),
    .rst_n                (rst_n),
    .data_in              (uart_rx_array_r),
    .msg_len              (dl_msg_len),
    .msg_tag              (dl_fec_msg_tag),
    .crc0_start           (dl_fec_crc0_start),
    .enc0_done            (dl_fec_enc0_done),
    .crc0_data_out        (dl_fec_crc0_data),
    .enc0_row_p           (dl_fec_enc0_row_p),
    .enc0_col_p           (dl_fec_enc0_col_p),
    .crc1_start           (dl_fec_crc1_start),
    .enc1_done            (dl_fec_enc1_done),
    .crc1_data_out        (dl_fec_crc1_data),
    .enc1_row_p           (dl_fec_enc1_row_p),
    .enc1_col_p           (dl_fec_enc1_col_p)
  );
  
  // ========= Downlink controller =========
  
  dl_controller #(
    .SERIAL_DIV_WIDTH  (SERIAL_DIV_WIDTH)
  ) dl_ctrl_u (
    .clk                  (clk),
    .rst_n                (rst_n),
    .data_in              (uart_rx_array_r),
    .msg_tag              (dl_fec_msg_tag),
    .msg_len              (dl_msg_len),
    .enc_used             (dl_ctrl_enc_used[0]),
    .dl_start             (dl_ctrl_start),
    .dl_done              (dl_ctrl_done),
    .dl_out               (dl_out),
    .dl_en                (dl_en),
    .crc0_data            (dl_fec_crc0_data),
    .enc0_row_p           (dl_fec_enc0_row_p),
    .enc0_col_p           (dl_fec_enc0_col_p),
    .crc1_data            (dl_fec_crc1_data),
    .enc1_row_p           (dl_fec_enc1_row_p),
    .enc1_col_p           (dl_fec_enc1_col_p),
    .ser_clk_div          (dl_ctrl_clk_div),
    .err_inj_mask_0       (dl_err_inj_mask_0),
    .err_inj_mask_1       (dl_err_inj_mask_1),
    .err_inj_enable       (dl_err_inj_enable),
    .err_inj_enable_clear (dl_err_inj_enable_clear)
   );
  
  // =========================================================
  // =                 Uplink data path                      =
  // =========================================================
  logic                                 ul_fec_enc_used;
  logic                                 ul_fec_enc0_start;
  logic [ENC0_DATA_WIDTH-1:0][ENC0_DATA_DEPTH-1:0] ul_fec_enc0_data_cor;
  logic                                 ul_fec_enc0_err_det;
  logic                                 ul_fec_enc0_err_cor;
  logic                                 ul_fec_crc0_done;
  logic                                 ul_fec_crc0_valid;
  logic                                 ul_fec_enc1_start;
  logic [ENC1_DATA_WIDTH-1:0][ENC1_DATA_DEPTH-1:0] ul_fec_enc1_data_cor;
  logic                                 ul_fec_enc1_err_det;
  logic                                 ul_fec_enc1_err_cor;
  logic                                 ul_fec_crc1_done;
  logic                                 ul_fec_crc1_valid;
  logic                                 ul_fec_uncor_err;
   // logic                                 ul_mon_done;
  logic                                 ul_fsm_msg_done;
  logic                                 ul_mon_enc_used;
  logic                                 ul_mon_data_rd;
  logic [UL_FIFO_FAW-1:0]               ul_mon_data_level;
  logic [2**UART_RX_FAW-2:0][UART_MDW-1:0] ul_mon_data_out;
  logic [CRC0_WIDTH-1:0]                ul_mon_crc0_data;
  logic [ENC0_DATA_DEPTH-1:0]           ul_mon_cenc0_row_p;
  logic [ENC0_DATA_WIDTH-1:0]           ul_mon_cenc0_col_p;
  logic [CRC1_WIDTH-1:0]                ul_mon_crc1_data;
  logic [ENC1_DATA_DEPTH-1:0]           ul_mon_enc1_row_p;
  logic [ENC1_DATA_WIDTH-1:0]           ul_mon_enc1_col_p;
  logic [7:0]                           ul_mon_msg_cnt;
  
  
  // ====== UL FEC Control FSM  =======

  ul_fec_fsm ul_fec_fsm_u (
    .clk                  (clk),
    .rst_n                (rst_n),
    .uart_tx_level        (uart_tx_level),
    .ul_uart_tx_wr        (ul_uart_tx_wr),
    .ul_uart_tx_wdata     (ul_uart_tx_wdata),
    .ul_uart_tx_grant     (ul_uart_tx_grant),
    .ul_uart_tx_req       (ul_uart_tx_req),
    // .ul_mon_done          (ul_mon_done),
    .ul_fsm_msg_done      (ul_fsm_msg_done),
    .ul_mon_enc_used      (ul_mon_enc_used),
    .ul_mon_data_rd       (ul_mon_data_rd),
    .ul_mon_data_level    (ul_mon_data_level),
    .ul_fec_enc_used      (ul_fec_enc_used),
    .ul_fec_enc0_start    (ul_fec_enc0_start),
    .ul_fec_enc0_data_cor (ul_fec_enc0_data_cor),
    .ul_fec_enc0_err_det  (ul_fec_enc0_err_det),
    .ul_fec_enc0_err_cor  (ul_fec_enc0_err_cor),
    .ul_fec_crc0_done     (ul_fec_crc0_done),
    .ul_fec_crc0_valid    (ul_fec_crc0_valid),
    .ul_fec_enc1_start    (ul_fec_enc1_start),
    .ul_fec_enc1_data_cor (ul_fec_enc1_data_cor),
    .ul_fec_enc1_err_det  (ul_fec_enc1_err_det),
    .ul_fec_enc1_err_cor  (ul_fec_enc1_err_cor),
    .ul_fec_crc1_done     (ul_fec_crc1_done),
    .ul_fec_crc1_valid    (ul_fec_crc1_valid)
  );

  // ========= Uplink monitor =========

  uplink_monitor  # (
    .SERIAL_DIV_WIDTH   (SERIAL_DIV_WIDTH)
  ) ul_mon_u (
    .clk              (clk),
    .rst_n            (rst_n),
    .ul_in            (ul_in),
    .ul_en            (ul_en),
    .msg_cnt          (ul_mon_msg_cnt),
    .ul_fec_enc_used  (ul_fec_enc_used),
    .ul_fec_done      (ul_fec_crc1_done),
    .ul_fec_uncor_err (ul_fec_uncor_err),
    // .done             (ul_mon_done),
    .msg_done         (ul_fsm_msg_done),
    .enc_used         (ul_mon_enc_used),
    .data_rd          (ul_mon_data_rd),
    .data_level       (ul_mon_data_level),
    .data_out         (ul_mon_data_out),
    .crc0_data        (ul_mon_crc0_data),
    .enc0_row_p       (ul_mon_cenc0_row_p),
    .enc0_col_p       (ul_mon_cenc0_col_p),
    .crc1_data        (ul_mon_crc1_data),
    .enc1_row_p       (ul_mon_enc1_row_p),
    .enc1_col_p       (ul_mon_enc1_col_p)
  );

  // ========== UL FEC Engine =========
  
  ul_fec_engine ul_fec_u (
    .clk              (clk),
    .rst_n            (rst_n),
    .uncor_err        (ul_fec_uncor_err),
    .enc_used         (ul_fec_enc_used),
    .data_in          (ul_mon_data_out),

    .enc0_start       (ul_fec_enc0_start),
    .enc0_row_p       (ul_mon_cenc0_row_p),
    .enc0_col_p       (ul_mon_cenc0_col_p),
    .enc0_data_cor    (ul_fec_enc0_data_cor),
    .enc0_err_det     (ul_fec_enc0_err_det),
    .enc0_err_cor     (ul_fec_enc0_err_cor),
    .crc0_data        (ul_mon_crc0_data),
    .crc0_done        (ul_fec_crc0_done),
    .crc0_valid       (ul_fec_crc0_valid),

    .enc1_start       (ul_fec_enc1_start),
    .enc1_row_p       (ul_mon_enc1_row_p),
    .enc1_col_p       (ul_mon_enc1_col_p),
    .enc1_data_cor    (ul_fec_enc1_data_cor),
    .enc1_err_det     (ul_fec_enc1_err_det),
    .enc1_err_cor     (ul_fec_enc1_err_cor),
    .crc1_data        (ul_mon_crc1_data),
    .crc1_done        (ul_fec_crc1_done),
    .crc1_valid       (ul_fec_crc1_valid)
  );

endmodule

import fec_pkg::*;

// ====== DL FEC Control FSM  =======

module dl_fec_fsm(
  input  logic                        clk,
  input  logic                        rst_n,
  output logic                        ready,
  // UART Control
  input  logic [2**UART_RX_FAW-1:0][UART_MDW-1:0] uart_rx_array,
  input  logic                        uart_rx_done,
  input  logic [UART_RX_FAW-1:0]      uart_rx_level,
  output logic                        uart_rx_fifo_flush,
  output logic                        uart_rx_fifo_reg,
  input  logic [UART_TX_FAW-1:0]      uart_tx_level,
  input  logic [1:0]                  uart_fatal_errors,
  // DL FEC Control
  output logic                        dl_uart_tx_wr,
  output logic [UART_MDW-1:0]         dl_uart_tx_wdata,
  input  logic                        dl_uart_tx_grant,
  output logic                        dl_uart_tx_req,
  output logic [7:0]                  dl_fec_msg_len,
  output logic [3:0]                  dl_fec_msg_tag,
  output logic                        dl_fec_crc0_start,
  input  logic                        dl_fec_enc0_done,
  output logic                        dl_fec_crc1_start,
  input  logic                        dl_fec_enc1_done,
  output logic [1:0]                  dl_ctrl_enc_used,
  output logic                        dl_ctrl_start,
  input  logic                        dl_ctrl_ser_en,
  // Register access
  output  logic                       psel,
  output  logic                       penable,
  output  logic                       pwrite,
  output  logic [APB_ADDR_WIDTH-1:0]  paddr,
  output  logic [APB_DATA_WIDTH-1:0]  pwdata,  
  input   logic [APB_DATA_WIDTH-1:0]  prdata,
  input   logic                       pslverr
  );
  
  typedef enum logic [4:0] {
    //S_UNDEF                   = 5'bx,
    S_IDLE                    = 5'd0,
    S_COMMAND                 = 5'd1,
    S_CMD_ERR_UART_TX_REQUEST = 5'd2,
    S_CMD_ERR_UART_TX_WRITE   = 5'd3,
    
    // FEC Message transmit
    S_MESSAGE_LENGHT_WAIT     = 5'd4, // Wait Message lenght
    S_MESSAGE_LENGHT          = 5'd5,
    S_MESSAGE_LENGHT_CHECK    = 5'd6,
    S_MESSAGE_TAG_WAIT        = 5'd7, // Wait Message tag
    S_MESSAGE_TAG             = 5'd8,
    S_FEC_START_ENCODE_1      = 5'd9, // Start 16-bit encoder
    S_FEC_DONE_ENCODE_1       = 5'd10,
    S_DLCTL_ENC1_START        = 5'd11,
    S_DLCTL_ENC1_EXIT         = 5'd12,
    
    S_MESSAGE_DATA_WAIT       = 5'd13,
    S_MESSAGE_DATA            = 5'd14,
    S_UART_RX_FIFO_REG        = 5'd15,
    S_FEC_START_ENCODE_0      = 5'd16, // Start 64-bit encoder
    S_FEC_DONE_ENCODE_0       = 5'd17,
    S_DLCTL_ENC0_START        = 5'd18,
    S_DLCTL_ENC0_EXIT         = 5'd19,
    
    S_MESSAGE_UART_TX_REQUEST = 5'd20,
    S_MESSAGE_UART_TX_WRITE   = 5'd21,
    
    // Register Access
    S_REG_ADDRESS_WAIT        = 5'd22, // Wait Register address
    S_REG_ADDRESS             = 5'd23,
    
    S_REG_WRITE_DATA_WAIT     = 5'd24, // Register Write
    S_REG_WRITE_APB_SET_DATA  = 5'd25, // S_REG_APB_WRITE_DATA relpaced
    S_REG_WRITE_TX_REQUEST    = 5'd26, // 
    S_REG_WRITE_TX_WRITE      = 5'd27, // 
        
    S_REG_READ_APB_GET_DATA   = 5'd28, // Register Read S_REG_APB_READ_DATA replaced
    S_REG_READ_TX_REQUEST     = 5'd29, // S_REG_UART_TX_REQUEST replaced
    S_REG_READ_TX_WRITE       = 5'd30  // S_REG_UART_TX_WRITE
    
   } state_fsm_dl_t;
    state_fsm_dl_t state, next_state;
  
  logic [UART_MDW-1:0] uart_rx_array_0;
  logic [3:0]  dl_cmd    , dl_msg_tag;
  logic [7:0]  dl_msg_len, dl_msg_cnt, dl_reg_addr;
  logic [31:0] dl_reg_rdata;
  logic dl_txn_done, dl_ready, dl_cmd_error;
  logic pslverr_r;
    
  logic                uart_tx_wr;
  logic [UART_MDW-1:0] uart_tx_wdata;
  logic                uart_tx_grant;
  logic                uart_tx_req;
  logic [1:0]          uart_fatal_errors_r;
  
  assign dl_uart_tx_wr    = uart_tx_wr;
  assign dl_uart_tx_wdata = uart_tx_wdata;
  assign uart_tx_grant    = dl_uart_tx_grant;
  assign dl_uart_tx_req   = uart_tx_req;
  
  assign dl_fec_msg_tag   = dl_msg_tag;
  assign dl_fec_msg_len   = dl_msg_len;
  assign ready            = dl_ready;
  assign uart_rx_array_0  = uart_rx_array[0];
  
  assign dl_ready = (uart_rx_level < 'd7);
  
  // Current state logic
  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n)
      state <= S_IDLE;
    else
      state <= next_state;
  end
  
  // Next state logic
  always_comb begin
    next_state = state;
    
    case(state)
      
      S_IDLE: begin 
        /*
        if(uart_fatal_errors)
          next_state = S_CMD_ERR_UART_TX_REQUEST;
        else*/ if(uart_rx_done)
          next_state = S_COMMAND;
        else 
          next_state = state;
      end
      
      S_COMMAND: begin
        case(uart_rx_array_0[3:0]) // command_t (dl_cmd)
          CMD_REG_READ:   next_state = S_REG_ADDRESS_WAIT;
          CMD_REG_WRITE:  next_state = S_REG_ADDRESS_WAIT;
          CMD_TX_MSG:     next_state = S_MESSAGE_LENGHT_WAIT;
          default:                   next_state = S_CMD_ERR_UART_TX_REQUEST;
        endcase       
      end
      
      // Command error response
      
      S_CMD_ERR_UART_TX_REQUEST: begin
        if(uart_tx_grant)
		      next_state = S_CMD_ERR_UART_TX_WRITE;
		    else
		      next_state = state;
      end
      
      S_CMD_ERR_UART_TX_WRITE: begin
        if(uart_tx_level=='d2)
          next_state = S_IDLE;
        else
          next_state = state;
	  end
            
      
      // Downlink FEC Transmit ====================================
      
      
      S_MESSAGE_LENGHT_WAIT: begin
        if(uart_fatal_errors)
          next_state = S_CMD_ERR_UART_TX_REQUEST;
        else if(uart_rx_done)
          next_state = S_MESSAGE_LENGHT;
        else
          next_state = state;
      end
      
      S_MESSAGE_LENGHT: begin
        next_state = S_MESSAGE_LENGHT_CHECK;
      end
      
      S_MESSAGE_LENGHT_CHECK: begin
        if(dl_msg_len > 'b0) begin
          next_state = S_MESSAGE_TAG_WAIT;
        end else
        //next_state = S_IDLE;
          next_state = S_CMD_ERR_UART_TX_REQUEST;
      end
      
      S_MESSAGE_TAG_WAIT: begin
        if(uart_fatal_errors)
          next_state= S_CMD_ERR_UART_TX_REQUEST;
        else if(uart_rx_done)
          next_state = S_MESSAGE_TAG;
        else
          next_state = state;
      end
      
      S_MESSAGE_TAG: begin
        next_state = S_FEC_START_ENCODE_1;
      end
      
      S_FEC_START_ENCODE_1: begin // 16-bit encoder
        next_state = S_FEC_DONE_ENCODE_1;
      end
      
      S_FEC_DONE_ENCODE_1:begin
        if(dl_fec_enc1_done && !dl_ctrl_ser_en)
          next_state = S_DLCTL_ENC1_START;
        else
          next_state = state;
      end
      
      S_DLCTL_ENC1_START: begin
        next_state = S_DLCTL_ENC1_EXIT;
      end
            
      S_DLCTL_ENC1_EXIT: begin
        next_state = S_MESSAGE_DATA_WAIT;
      end
      
      S_MESSAGE_DATA_WAIT: begin
        if(uart_fatal_errors)
          next_state= S_CMD_ERR_UART_TX_REQUEST;
        else if(uart_rx_done)
          next_state = S_MESSAGE_DATA;
        else
          next_state = state;
      end
            
      S_MESSAGE_DATA: begin
        if(/*uart_rx_done && */(uart_rx_level=='d7 | dl_msg_cnt >= dl_msg_len))
          next_state = S_UART_RX_FIFO_REG;
        else
          next_state = S_MESSAGE_DATA_WAIT;
      end
      
      S_UART_RX_FIFO_REG: begin
        next_state = S_FEC_START_ENCODE_0;
      end
      
      S_FEC_START_ENCODE_0: begin // 64-bit encoder
      //if(!dl_ctrl_ser_en)
          next_state = S_FEC_DONE_ENCODE_0;
      //else
      //  next_state = state;
      end
      
      S_FEC_DONE_ENCODE_0:begin
        if(dl_fec_enc0_done)
          next_state = S_DLCTL_ENC0_START;
        else
          next_state = state;
      end
      
      S_DLCTL_ENC0_START: begin
        if(!dl_ctrl_ser_en)
          next_state = S_DLCTL_ENC0_EXIT;
        else
          next_state = state;
      end
            
      S_DLCTL_ENC0_EXIT: begin
      //if(dl_msg_cnt>=dl_msg_len)
        if(dl_txn_done)
          //next_state = S_IDLE;
          next_state = S_MESSAGE_UART_TX_REQUEST;
        else
          next_state = S_MESSAGE_DATA;
      end
      
      S_MESSAGE_UART_TX_REQUEST: begin
        if(uart_tx_grant)
		      next_state = S_MESSAGE_UART_TX_WRITE;
		    else
		      next_state = state;
      end
      
      S_MESSAGE_UART_TX_WRITE: begin
        if(uart_tx_level=='d3)
          next_state = S_IDLE;
        else
          next_state = state;
      end
      
      
      // Register access =========================================
      
      
      S_REG_ADDRESS_WAIT: begin
        if(uart_fatal_errors)
          next_state= S_CMD_ERR_UART_TX_REQUEST;
        else if(uart_rx_done)
          next_state = S_REG_ADDRESS;
        else
          next_state = state;
      end
      
      S_REG_ADDRESS: begin        
        case(dl_cmd) // command_t
            CMD_REG_READ:  next_state = S_REG_READ_APB_GET_DATA;
            CMD_REG_WRITE: next_state = S_REG_WRITE_DATA_WAIT;
            default: next_state = state;
          endcase
	  end
      
      
      // Register write ==========================
      
      
      S_REG_WRITE_DATA_WAIT: begin
        if(uart_rx_level=='d4)
          next_state = S_REG_WRITE_APB_SET_DATA;
        else
          next_state = state;
      end
      
      S_REG_WRITE_APB_SET_DATA: begin
        next_state = S_REG_WRITE_TX_REQUEST;
      end
      
      S_REG_WRITE_TX_REQUEST: begin
        if(uart_tx_grant)
		      next_state = S_REG_WRITE_TX_WRITE;
		    else
		      next_state = state;
      end
      
      S_REG_WRITE_TX_WRITE: begin
        if(uart_tx_level=='d2)
          next_state = S_IDLE;
        else
          next_state = state;
      end
      
      
      // Read Register ==========================
      
      
      S_REG_READ_APB_GET_DATA: begin
        next_state = S_REG_READ_TX_REQUEST;
      end
	  
	  S_REG_READ_TX_REQUEST: begin
	    if(uart_tx_grant)
		    next_state = S_REG_READ_TX_WRITE;
		  else
		  next_state = state;
	  end
	  
	  S_REG_READ_TX_WRITE: begin
	    if(uart_tx_level=='d4)
        next_state = S_IDLE;
      else
        next_state = state;
	  end
	        
    endcase
  end
  
  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      dl_cmd             <= 'b0;
      dl_cmd_error       <= 1'b0;
      dl_msg_len         <= 'b0;
      dl_msg_cnt         <= 'b0;
      dl_msg_tag         <= 'b0;
      dl_reg_addr        <= 'b0;
      dl_reg_rdata       <= 'b0;
      dl_txn_done        <= 'b0;
      
      uart_rx_fifo_flush <= 'b0;
      uart_rx_fifo_reg   <= 'b0;
      uart_tx_wr         <= 1'b0;
      uart_tx_wdata      <=  'b0;
      uart_tx_req        <= 1'b0;
      uart_fatal_errors_r<= 2'b0;
      
      dl_fec_crc0_start  <= 'b0;
      dl_fec_crc1_start  <= 'b0;
      dl_ctrl_start      <= 'b0;
      dl_ctrl_enc_used   <= 'b11; // default
      
      psel               <= 'b0;
      penable            <= 'b0;
      pwrite             <= 'b0;
      paddr              <= 'b0;
      pwdata             <= 'b0;
      pslverr_r          <= 1'b0;
    end
    else begin
            
      case(state)
        
        S_IDLE: begin
          dl_cmd             <= 'b0;
          dl_cmd_error       <= 1'b0;
          dl_msg_len         <= 'b0;
          dl_msg_cnt         <= 'b0;
          dl_msg_tag         <= 'b0;
          dl_reg_addr        <= 'b0;
          dl_reg_rdata       <= 'b0;
          dl_txn_done        <= 'b0;
          
          uart_rx_fifo_flush <= 'b0;
          uart_rx_fifo_reg   <= 'b0;
          uart_tx_wr         <= 1'b0;
          uart_tx_wdata      <= 8'b0;
          uart_tx_req        <= 1'b0;
          uart_fatal_errors_r<= uart_fatal_errors;
          
          dl_fec_crc0_start  <= 'b0;
          dl_fec_crc1_start  <= 'b0;
          dl_ctrl_start      <= 'b0;
          dl_ctrl_enc_used   <= 'b11;
          
          psel               <= 'b0;
          penable            <= 'b0;
          pwrite             <= 'b0;
          paddr              <= 'b0;
          pwdata             <= 'b0;
          pslverr_r          <= 1'b0;
        end
        
        S_COMMAND: begin
          dl_cmd             <= uart_rx_array_0[3:0];
          uart_rx_fifo_flush <= 'b1;
          unique case(uart_rx_array_0[3:0]) // command_t
            CMD_REG_READ:  dl_cmd_error <= 1'b0;
            CMD_REG_WRITE: dl_cmd_error <= 1'b0;
            CMD_TX_MSG:    dl_cmd_error <= 1'b0;
            default:       dl_cmd_error <= 1'b1;
          endcase
        end
        
        S_CMD_ERR_UART_TX_REQUEST: begin
          uart_tx_req        <= 1'b1;
        end
        
        S_CMD_ERR_UART_TX_WRITE: begin
          if(uart_tx_level=='d0 & uart_tx_wr==1'b0) begin     // Command ID (command_t)
            uart_tx_wr    <= 1'b1;
            uart_tx_wdata <= RSP_CMD_ERR;
          end
          else if(uart_tx_level=='d1 & uart_tx_wr==1'b0) begin // Command error
            uart_tx_wr    <= 1'b1;
            uart_tx_wdata <= {4'b0,
                              (dl_msg_len=='b0)?1'b1:1'b0,
                              uart_fatal_errors_r,
                              dl_cmd_error};
          end
          else begin
            uart_tx_wr    <= 1'b0;
            uart_tx_wdata <= 8'b0;
          end
          
        end
        
        
        // FEC downlink transmit ===================================
        
        
        S_MESSAGE_LENGHT_WAIT: begin
          uart_rx_fifo_flush <= 'b0;
          uart_fatal_errors_r<= uart_fatal_errors;
        end
        
        S_MESSAGE_LENGHT: begin
          dl_msg_len         <= uart_rx_array_0;
          uart_rx_fifo_flush <= 'b1;
        end
        
        S_MESSAGE_LENGHT_CHECK: begin
          uart_rx_fifo_flush <= 'b0;
        end
        
         S_MESSAGE_TAG_WAIT: begin
           uart_fatal_errors_r<= uart_fatal_errors;
         end
        
        S_MESSAGE_TAG: begin
          dl_msg_tag         <= uart_rx_array_0[3:0];
          uart_rx_fifo_flush <= 'b1;
        end
        
        S_FEC_START_ENCODE_1: begin // 16-bit encoding cluster
          uart_rx_fifo_flush <= 'b0;
          dl_fec_crc1_start  <= 'b1;
        end
        
        S_FEC_DONE_ENCODE_1: begin
          dl_ctrl_enc_used   <= 'b1;
          dl_fec_crc1_start  <= 'b0;
        end
        
        S_DLCTL_ENC1_START: begin
          dl_ctrl_start      <= 'b1;
        end
        
        S_DLCTL_ENC1_EXIT: begin
          dl_ctrl_start      <= 'b0;
        end
                
        S_MESSAGE_DATA_WAIT: begin
          uart_fatal_errors_r<= uart_fatal_errors;
          if(uart_rx_done)
            dl_msg_cnt <= dl_msg_cnt + 8'b1;
          else
            dl_msg_cnt <= dl_msg_cnt;
        end
        
        S_MESSAGE_DATA: begin
         if(/*uart_rx_level=='d7 ||*/ dl_msg_cnt>=dl_msg_len) begin
           dl_txn_done        <= 'b1;
          //  uart_rx_fifo_flush <= 'b1;
          //  dl_msg_cnt <= 'b0;
          end
          else
            dl_txn_done <= dl_txn_done;
          //else
          //  uart_rx_fifo_flush <= 'b0;
        end
        
        S_UART_RX_FIFO_REG: begin
          uart_rx_fifo_reg   <= 'b1;
        end
        
        S_FEC_START_ENCODE_0: begin // 64-bit encoding cluster
          uart_rx_fifo_reg   <= 'b0;
          dl_fec_crc0_start  <= 'b1;
        end
        
        S_FEC_DONE_ENCODE_0: begin
          dl_ctrl_enc_used   <= 'b0;
          dl_fec_crc0_start  <= 'b0;
        end
        
        S_DLCTL_ENC0_START: begin
          uart_rx_fifo_flush <= 'b1;
          dl_ctrl_start      <= 'b1;
        end
        
        S_DLCTL_ENC0_EXIT: begin
          uart_rx_fifo_flush <= 'b0;
          dl_ctrl_start      <= 'b0;
        end
        
        S_MESSAGE_UART_TX_REQUEST: begin
          uart_tx_req        <= 1'b1;
        end
        
        S_MESSAGE_UART_TX_WRITE: begin
          if(uart_tx_level=='d0 & uart_tx_wr==1'b0) begin       // Command ID (command_t)
            uart_tx_wr    <= 1'b1;
            uart_tx_wdata <= RSP_TX_RES;
          end
          else if(uart_tx_level=='d1 & uart_tx_wr==1'b0) begin  // Message Tag
            uart_tx_wr    <= 1'b1;
            uart_tx_wdata <= dl_msg_tag;
            //$display("[%0t][DE.FEC_FSM] S_MESSAGE_UART_TX_WRITE dl_msg_tag: %0d", $time, dl_msg_tag);
          end
          else if(uart_tx_level=='d2 & uart_tx_wr==1'b0) begin
            uart_tx_wr    <= 1'b1;
            uart_tx_wdata <= 8'b0; // Transmit result: Success
          end
          else begin
            uart_tx_wr    <= 1'b0;
            uart_tx_wdata <= 'b0;
          end
        end
        
        
        // Register access ========================================
        
        
        S_REG_ADDRESS_WAIT: begin
          uart_fatal_errors_r<= uart_fatal_errors;
          uart_rx_fifo_flush <= 'b0;
        end
        
        S_REG_ADDRESS: begin
          uart_rx_fifo_flush <= 'b1;
          dl_reg_addr <= uart_rx_array_0;
        end
        
        
        // Register write =========================
        
        
        S_REG_WRITE_DATA_WAIT: begin
          uart_rx_fifo_flush <= 'b0;
        end
        
        S_REG_WRITE_APB_SET_DATA: begin
          psel               <= 'b1;
          penable            <= 'b1;
          pwrite             <=  REG_WRITE; // register_op
          paddr              <=  dl_reg_addr;
          pwdata             <=  {uart_rx_array[0],  // MSB
                                  uart_rx_array[1],
                                  uart_rx_array[2],
                                  uart_rx_array[3]}; // LSB
          uart_rx_fifo_flush <= 'b1;
        end
        
        S_REG_WRITE_TX_REQUEST: begin
          psel               <= 'b0;
          penable            <= 'b0;
          pwrite             <= 'b0;
          paddr              <= 8'b0;
          pwdata             <= 32'b0;
          uart_rx_fifo_flush <= 'b0;
          uart_tx_req        <= 1'b1;
          pslverr_r          <= pslverr;
        end
      
        S_REG_WRITE_TX_WRITE: begin
          if(uart_tx_level=='d0 & uart_tx_wr==1'b0) begin       // Command ID (command_t)
            uart_tx_wr    <= 1'b1;
            uart_tx_wdata <= RSP_WRITE_RES;
          end
          else if(uart_tx_level=='d1 & uart_tx_wr==1'b0) begin // Register Address
            uart_tx_wr    <= 1'b1;
            uart_tx_wdata <= dl_reg_addr;
          end
          else if(uart_tx_level=='d2 & uart_tx_wr==1'b0) begin // Access Result
            uart_tx_wr    <= 1'b1;
            uart_tx_wdata <= {7'b0, pslverr_r};
          end
          else begin
            uart_tx_wr    <= 1'b0;
            uart_tx_wdata <= 'b0;
          end
        end
        
        
        // Register read ===========================
        
        
        S_REG_READ_APB_GET_DATA: begin
          psel               <= 'b1;
          penable            <= 'b1;
          pwrite             <=  REG_READ; // register_op
          paddr              <=  dl_reg_addr;
          //dl_reg_rdata       <= prdata;
        end
        
        S_REG_READ_TX_REQUEST: begin
          uart_tx_req        <= 1'b1;
          dl_reg_rdata       <= prdata;
        end
        
        S_REG_READ_TX_WRITE: begin
          psel               <= 'b0;
          penable            <= 'b0;
          pwrite             <= 'b0;
          paddr              <= 8'b0;
          
          //$display("[%0t]  S_REG_UART_TX_WRITE uart_tx_level: %0h uart_tx_wr: %0h ", $time, uart_tx_level, uart_tx_wr);
          if(uart_tx_level=='d0 & uart_tx_wr==1'b0) begin      // Command ID (command_t)
            uart_tx_wr    <= 1'b1;
            uart_tx_wdata <= RSP_READ_RES;
          end
          else if(uart_tx_level=='d1 & uart_tx_wr==1'b0) begin // 
            uart_tx_wr    <= 1'b1;
            uart_tx_wdata <= dl_reg_rdata[31:24];
          end
          else if(uart_tx_level=='d2 & uart_tx_wr==1'b0) begin
            uart_tx_wr    <= 1'b1;
            uart_tx_wdata <= dl_reg_rdata[23:16];
          end
          else if(uart_tx_level=='d3 & uart_tx_wr==1'b0) begin
            uart_tx_wr    <= 1'b1;
            uart_tx_wdata <= dl_reg_rdata[15:8];
          end
          else if(uart_tx_level=='d4 & uart_tx_wr==1'b0) begin // UART TX LSB
            uart_tx_wr    <= 1'b1;
            uart_tx_wdata <= dl_reg_rdata[7:0];
          end
          else begin
            uart_tx_wr    <= 1'b0;
            uart_tx_wdata <= 'b0;
          end
        end
        
        default: begin
          dl_cmd             <= 'b0;
          dl_cmd_error       <= 1'b0;
          dl_msg_len         <= 'b0;
          dl_msg_cnt         <= 'b0;
          dl_msg_tag         <= 'b0;
          dl_reg_addr        <= 'b0;
          dl_reg_rdata       <= 'b0;
          dl_txn_done        <= 'b0;
          
          uart_rx_fifo_flush <= 'b0;
          uart_rx_fifo_reg   <= 'b0;
          uart_tx_wr         <= 1'b0;
          uart_tx_wdata      <=  'b0;
          uart_fatal_errors_r<= 2'b0;
          uart_tx_req        <= 1'b0;
          
          dl_fec_crc0_start  <= 'b0;
          dl_fec_crc1_start  <= 'b0;
          dl_ctrl_start      <= 'b0;
          dl_ctrl_enc_used   <= 'b11; // default
      
          psel               <= 'b0;
          penable            <= 'b0;
          pwrite             <= 'b0;
          paddr              <= 'b0;
          pwdata             <= 'b0;
          pslverr_r          <= 1'b0;
        end
        
      endcase
        
    end
       
  end

endmodule

// ====== UL FEC Control FSM  =======

module ul_fec_fsm(
  input  logic                    clk,
  input  logic                    rst_n,
  // UART TX Control
  input  logic [UART_TX_FAW-1:0]  uart_tx_level,
  output logic                    ul_uart_tx_wr,
  output logic [UART_MDW-1:0]     ul_uart_tx_wdata,
  input  logic                    ul_uart_tx_grant,
  output logic                    ul_uart_tx_req,
  // Inputs from Uplink monitor
  // input  logic                ul_mon_done,
  output logic                    ul_fsm_msg_done,
  input  logic                    ul_mon_enc_used,
  output logic                    ul_mon_data_rd,
  input  logic [UL_FIFO_FAW-1:0]  ul_mon_data_level,
  // Outputs to UL FEC Engine
  output logic                    ul_fec_enc_used,

  output logic                    ul_fec_enc0_start,
  input  logic [ENC0_DATA_WIDTH-1:0][ENC0_DATA_DEPTH-1:0] ul_fec_enc0_data_cor,
  input  logic                    ul_fec_enc0_err_det,
  input  logic                    ul_fec_enc0_err_cor,
  input  logic                    ul_fec_crc0_done,
  input  logic                    ul_fec_crc0_valid,

  output logic                    ul_fec_enc1_start,
  input  logic [ENC1_DATA_WIDTH-1:0][ENC1_DATA_DEPTH-1:0] ul_fec_enc1_data_cor,
  input  logic                    ul_fec_enc1_err_det,
  input  logic                    ul_fec_enc1_err_cor,
  input  logic                    ul_fec_crc1_done,
  input  logic                    ul_fec_crc1_valid
  );

  typedef enum logic [3:0] {
      S_IDLE                    = 4'd0,
      S_READ_MON_DATA           = 4'd1,
      S_UART_TX_REQUEST         = 4'd2,
      S_FEC_CLUST1_START        = 4'd3,
      S_FEC_CLUST1_DECODING     = 4'd4,
      S_UART_TX_WRITE_MSG_ID    = 4'd5,
      S_FEC_CLUST0_START        = 4'd6,
      S_FEC_CLUST0_DECODING     = 4'd7,
      S_UART_TX_WRITE_MSG_DATA  = 4'd8
  } state_fsm_ul_t;
  state_fsm_ul_t ul_state, next_ul_state;

  logic                uart_tx_wr;
  logic [UART_MDW-1:0] uart_tx_wdata;
  logic                uart_tx_grant;
  logic                uart_tx_req;
  logic                msg_done;
  logic [7:0]          msg_len, msg_cnt, msg_cnt_p1;
  assign ul_uart_tx_wr    = uart_tx_wr;
  assign ul_uart_tx_wdata = uart_tx_wdata;
  assign uart_tx_grant    = ul_uart_tx_grant;
  assign ul_uart_tx_req   = uart_tx_req;
  assign msg_cnt_p1       = msg_cnt + 1'b1;
  assign ul_fsm_msg_done  = msg_done;
  
  // Current state logic
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
        
        if(ul_mon_data_level > 'b0)
          next_ul_state = S_READ_MON_DATA;
        //  if(ul_mon_done) begin
        //    if(ul_fec_enc_used)
        //      next_ul_state = S_FEC_CLUST1_START;
        //    else
        //      next_ul_state = S_FEC_CLUST0_START;
        // end
      end

      S_READ_MON_DATA: begin
        if(!ul_fec_enc_used || !msg_done)
            next_ul_state = S_FEC_CLUST0_START;
          else
            next_ul_state = S_FEC_CLUST1_START;
      end

      S_UART_TX_REQUEST: begin
        if(uart_tx_grant) begin
          if(msg_done)
            next_ul_state = S_UART_TX_WRITE_MSG_ID;
          else
            next_ul_state = S_UART_TX_WRITE_MSG_DATA;
        end
      end
      
      S_FEC_CLUST1_START: begin
        next_ul_state = S_FEC_CLUST1_DECODING;
      end
      
      S_FEC_CLUST1_DECODING: begin
        if(ul_fec_crc1_done)
          next_ul_state = S_UART_TX_REQUEST;
      end

      S_UART_TX_WRITE_MSG_ID: begin
        if(uart_tx_level=='d4)
          next_ul_state = S_IDLE;
      end
      
      S_FEC_CLUST0_START: begin
        next_ul_state = S_FEC_CLUST0_DECODING;
      end
      
      S_FEC_CLUST0_DECODING: begin
        if(ul_fec_crc0_done)
          next_ul_state = S_UART_TX_REQUEST;
      end

      S_UART_TX_WRITE_MSG_DATA: begin
        if(uart_tx_level=='d10)
          next_ul_state = S_IDLE;
      end
      
      default: begin
        next_ul_state = S_IDLE;
      end
      
    endcase
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      ul_fec_enc0_start <= 1'b0;
      ul_fec_enc1_start <= 1'b0;
      ul_fec_enc_used   <= 1'b0;
      uart_tx_req       <= 1'b0;
      uart_tx_wr        <= 1'b0;
      uart_tx_wdata     <= 8'b0;
      msg_cnt           <= 8'b0;
      msg_len           <= 8'b0;
      msg_done          <= 1'b1; // Msg is done by default
      ul_mon_data_rd    <= 1'b0;
    end
    else begin
        
      case(ul_state)
        
        S_IDLE: begin
          ul_fec_enc0_start <= 1'b0;
          ul_fec_enc1_start <= 1'b0;
          ul_fec_enc_used   <= ul_mon_enc_used;
          uart_tx_req       <= 1'b0;
          uart_tx_wr        <= 1'b0;
          uart_tx_wdata     <= 8'b0;
          // msg_cnt           <= 8'b0;
          // msg_len           <= 8'b0;
          // msg_done          <= 1'b1; // Msg is done by default
          ul_mon_data_rd    <= 1'b0;
        end

        S_READ_MON_DATA: begin
          // ul_mon_data_rd    <= 1'b0;
        end
        
        S_UART_TX_REQUEST: begin
          uart_tx_req       <= 1'b1;
        end

        S_FEC_CLUST1_START: begin
          ul_fec_enc1_start <= 'b1;
          ul_fec_enc_used   <= 'b1;
        end
        
        S_FEC_CLUST1_DECODING: begin
          ul_fec_enc1_start <= 'b0;
        end

        S_UART_TX_WRITE_MSG_ID: begin
          if(uart_tx_level=='d0 & uart_tx_wr==1'b0) begin       // Command ID (command_t)
            uart_tx_wr    <= 1'b1;
            uart_tx_wdata <= RX_MSG_ID;
          end
          else if(uart_tx_level=='d1 & uart_tx_wr==1'b0) begin  // Message length
            uart_tx_wr    <= 1'b1;
            uart_tx_wdata <= {ul_fec_enc1_data_cor[2][3:0],ul_fec_enc1_data_cor[1][3:0]};
            msg_len       <= {ul_fec_enc1_data_cor[2][3:0],ul_fec_enc1_data_cor[1][3:0]};
          end
          else if(uart_tx_level=='d2 & uart_tx_wr==1'b0) begin  // Message tag
            uart_tx_wr    <= 1'b1;
            uart_tx_wdata <= {4'b0, ul_fec_enc1_data_cor[0][3:0]};
          end
          else if(uart_tx_level=='d3 & uart_tx_wr==1'b0) begin  // Reception validation
            uart_tx_wr    <= 1'b1;
            uart_tx_wdata <= {5'b0,
                              ul_fec_enc1_err_cor, // ERROR_CORRECTED
                              ul_fec_enc1_err_det, // ERROR_DETECTED
                              ~ul_fec_crc1_valid}; // CRC_ERROR
            ul_mon_data_rd <= 1'b1;
          end
          else begin
            uart_tx_wr      <= 1'b0;
            uart_tx_wdata   <= 8'b0;
            ul_mon_data_rd  <= 1'b0;
          end
        end
        
        S_FEC_CLUST0_START: begin
          ul_fec_enc0_start <= 'b1;
          ul_fec_enc_used   <= 'b0;
          msg_done          <= 1'b0;
        end
        
        S_FEC_CLUST0_DECODING: begin
          ul_fec_enc0_start <= 'b0;
        end
        
        S_UART_TX_WRITE_MSG_DATA: begin
          if(uart_tx_level=='d0 & uart_tx_wr==1'b0) begin       // Command ID (command_t)
            uart_tx_wr    <= 1'b1;
            uart_tx_wdata <= RX_MSG_DATA;
          end
          else if(uart_tx_level=='d1 & uart_tx_wr==1'b0) begin  // Message byte count
            uart_tx_wr    <= 1'b1;
            uart_tx_wdata <= msg_cnt;
          end
          else if(uart_tx_level=='d2 & uart_tx_wr==1'b0) begin  // Message data 0
            uart_tx_wr    <= 1'b1;
            uart_tx_wdata <= ul_fec_enc0_data_cor[0][7:0];
            msg_cnt       <= msg_cnt_p1;
          end
          else if(uart_tx_level=='d3 & uart_tx_wr==1'b0) begin  // Message data 1
            uart_tx_wr    <= 1'b1;
            uart_tx_wdata <= ul_fec_enc0_data_cor[1][7:0];
            msg_cnt       <= msg_cnt_p1;
          end
          else if(uart_tx_level=='d4 & uart_tx_wr==1'b0) begin  // Message data 2
            uart_tx_wr    <= 1'b1;
            uart_tx_wdata <= ul_fec_enc0_data_cor[2][7:0];
            msg_cnt       <= msg_cnt_p1;
          end
          else if(uart_tx_level=='d5 & uart_tx_wr==1'b0) begin  // Message data 3
            uart_tx_wr    <= 1'b1;
            uart_tx_wdata <= ul_fec_enc0_data_cor[3][7:0];
            msg_cnt       <= msg_cnt_p1;
          end
          else if(uart_tx_level=='d6 & uart_tx_wr==1'b0) begin  // Message data 4
            uart_tx_wr    <= 1'b1;
            uart_tx_wdata <= ul_fec_enc0_data_cor[4][7:0];
            msg_cnt       <= msg_cnt_p1;
          end
          else if(uart_tx_level=='d7 & uart_tx_wr==1'b0) begin  // Message data 5
            uart_tx_wr    <= 1'b1;
            uart_tx_wdata <= ul_fec_enc0_data_cor[5][7:0];
            msg_cnt       <= msg_cnt_p1;
          end
          else if(uart_tx_level=='d8 & uart_tx_wr==1'b0) begin  // Message data 6
            uart_tx_wr    <= 1'b1;
            uart_tx_wdata <= ul_fec_enc0_data_cor[6][7:0];
            msg_cnt       <= msg_cnt_p1;
          end
          else if(uart_tx_level=='d9 & uart_tx_wr==1'b0) begin  // Reception validation
            uart_tx_wr    <= 1'b1;
            uart_tx_wdata <= {5'b0,
                              ul_fec_enc0_err_cor, // ERROR_CORRECTED
                              ul_fec_enc0_err_det, // ERROR_DETECTED
                              ~ul_fec_crc0_valid}; // CRC_ERROR
            ul_mon_data_rd <= 1'b1;
            if(msg_cnt >= msg_len) begin
              msg_cnt   <= 8'b0;
              msg_len   <= 8'b0;
              msg_done  <= 1'b1;
            end
            else begin
              msg_cnt   <= msg_cnt;
              msg_len   <= msg_len;
              msg_done  <= msg_done;
            end

          end
          else begin
            uart_tx_wr      <= 1'b0;
            uart_tx_wdata   <= 8'b0;
            ul_mon_data_rd  <= 1'b0;
          end
        end
        
        default: begin
          ul_fec_enc0_start <= 1'b0;
          ul_fec_enc1_start <= 1'b0;
          ul_fec_enc_used   <= 1'b0;
          uart_tx_req       <= 1'b0;
          uart_tx_wr        <= 1'b0;
          uart_tx_wdata     <= 8'b0;
          msg_cnt           <= 8'b0;
          msg_len           <= 8'b0;
          msg_done          <= 1'b0;
        end
        
      endcase
        
    end

  end

endmodule
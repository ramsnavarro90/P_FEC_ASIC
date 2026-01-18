
`ifndef _DEFINES_SVH_
`define _DEFINES_SVH_
  // System
  `define SYS_CLK_PERIOD         20
  `define SYS_CLK_EDGE           (`SYS_CLK_PERIOD/2)
  `define SYS_CLK_FREQ           (1e9/`SYS_CLK_PERIOD)

package fec_pkg;

  parameter int APB_DATA_WIDTH         = 32;
  parameter int APB_ADDR_WIDTH         = 8;

  parameter int UART_MDW               = 8;
  parameter int UART_TX_FAW            = 4; // Depth = 16
  parameter int UART_RX_FAW            = 3; // Depth = 8
  parameter int UART_SC                = 8;
  parameter int UART_GFLEN             = 4;
  parameter int UART_PARITY_TYPE       = 1; // 000: None, 001: odd, 010: even, 100: Sticky 0, 101: Sticky 1

  // CRC-Encoder 0 Params
  parameter int                    CRC0_DATA_WIDTH        = 56; // 56b data + 8b CRC = 64b
  parameter int                    CRC0_WIDTH             = 8;
  parameter logic [CRC0_WIDTH:0]   CRC0_POLY              = 9'b10000111;
  parameter logic [CRC0_WIDTH-1:0] CRC0_SEED              = '0;
  parameter int                    CRC0_XOR_OPS_PER_CYCLE = 8;
  parameter int                    ENC0_DATA_WIDTH        = 8; // 8x8=64bits
  parameter int                    ENC0_DATA_DEPTH        = 8;
  parameter int                    ENC0_PAR_DATA_WIDTH    = 10;
  parameter int                    ENC0_PAR_DATA_DEPTH    = 8;
  parameter int                    ENC0_SERIAL_DATA_WIDTH = ENC0_PAR_DATA_WIDTH * (ENC0_DATA_DEPTH-1) + // Data
                                                            ENC0_PAR_DATA_WIDTH + ENC0_DATA_DEPTH +     // Parity
                                                            CRC0_WIDTH;                                 // CRC
  
  // CRC-Encoder 1 Params
  parameter int                    CRC1_DATA_WIDTH        = 12; // 12b data + 4b CRC = 16b
  parameter int                    CRC1_WIDTH             = 4;
  parameter logic [CRC1_WIDTH:0]   CRC1_POLY              = 'b10011;
  parameter logic [CRC1_WIDTH-1:0] CRC1_SEED              = '0;
  parameter int                    CRC1_XOR_OPS_PER_CYCLE = 4;
  parameter int                    ENC1_DATA_WIDTH        = 4; // 4x4=16bits
  parameter int                    ENC1_DATA_DEPTH        = 4;
  parameter int                    ENC1_PAR_DATA_WIDTH    = 6;
  parameter int                    ENC1_PAR_DATA_DEPTH    = 4;
  parameter int                    ENC1_SERIAL_DATA_WIDTH = ENC1_PAR_DATA_WIDTH * (ENC1_DATA_DEPTH-1) + // Data
                                                            ENC1_PAR_DATA_WIDTH + ENC1_DATA_DEPTH +     // Parity
                                                            CRC1_WIDTH;                                 // CRC
  // Serializer
  parameter int                    SERIAL_CLK_DIV         = 4;
  parameter int                    SERIAL_DIV_WIDTH       = 16; // Serializer clock div width
  parameter int                    SERIAL_DATA_WIDTH      = ENC0_PAR_DATA_WIDTH;
  parameter int                    SERIAL_DATA_DEPTH      = ENC0_PAR_DATA_DEPTH;

  parameter int                    DL_PREAMBLE_COUNT      = 4;

// UL FIFO
  localparam int UART_RX_WIDTH  = (2**UART_RX_FAW-1)*(UART_MDW);
  localparam int UL_FIFO_WIDTH  = UART_RX_WIDTH +    // Data
                                  ENC0_DATA_WIDTH +  // Col Parity
                                  ENC0_DATA_DEPTH +  // Row Parity
                                  CRC0_WIDTH +       // CRC
                                  1;                 // Sampling
  localparam int UL_FIFO_FAW    = 4;                 // Depth = 16

  localparam int COL_START      = 0;
  localparam int COL0_END       = COL_START  + ENC0_DATA_WIDTH - 1;
  localparam int COL1_END       = COL_START  + ENC1_DATA_WIDTH - 1;
  localparam int ROW_START      = COL0_END   + 1;
  localparam int ROW0_END       = ROW_START  + ENC0_DATA_DEPTH - 1;
  localparam int ROW1_END       = ROW_START  + ENC1_DATA_DEPTH - 1;
  localparam int CRC_START      = ROW0_END   + 1;
  localparam int CRC0_END       = CRC_START  + CRC0_WIDTH - 1;
  localparam int CRC1_END       = CRC_START  + CRC1_WIDTH - 1;
  localparam int DATA_START     = CRC0_END   + 1;
  localparam int DATA_END       = DATA_START + UART_RX_WIDTH - 1;
  localparam int SAMP_BIT       = UL_FIFO_WIDTH - 1;

  typedef enum bit [3:0] {
    CMD_REG_READ    = 4'd0, // Register read (*1)
    RSP_READ_RES    = 4'd1, // Register read result (*2)
    CMD_REG_WRITE   = 4'd2, // Register write (*1)
    RSP_WRITE_RES   = 4'd3, // Register write result (*2)
    CMD_TX_MSG      = 4'd4, // Transmit data (with DL FEC Datapath) (*1)
    RSP_TX_RES      = 4'd5, // Transmit data result (*2)
    RX_MSG_ID       = 4'd6, // Receive Message ID (with UL FEC datapath) (*3)
    RX_MSG_DATA     = 4'd7, // Receive Message data (with UL FEC datapath) (*3)
    RSP_CMD_ERR     = 4'd15 // Command error response (*4)
  } command_t;

  // 1: Input commnads to FEC module
  // 2: Response commands from FEC module
  // 3: Message recepction from FEC module
  // 4: Error response from a given commnand

  typedef enum bit {
    REG_READ  = 1'd0,
    REG_WRITE = 1'd1
  } register_op;

  typedef enum bit[7:0] {
    REG_ADDR_DL_SER_CLK_DIV    = 8'h00,
    REG_ADDR_DL_ERR_INJ_MASK_0 = 8'h04,
    REG_ADDR_DL_ERR_INJ_MASK_1 = 8'h08,
    REG_ADDR_DL_ERR_INJ_ENABLE = 8'h0c,
    REG_ADDR_UART_PR           = 8'h20,
    REG_ADDR_UART_CTRL         = 8'h24,
    REG_ADDR_UART_CFG          = 8'h28    
  } reg_addr_t;

  typedef enum int {
    UART_NO_ERR = 0,
    UART_RX_RTO_COMMAND,
    UART_RX_RTO_MSG_LENGHT,
    UART_RX_RTO_MSG_TAG,
    UART_RX_RTO_DATA,
    UART_RX_RTO_DATA_BITS,
    UART_RX_FER
  } uart_error_t;

endpackage

`endif




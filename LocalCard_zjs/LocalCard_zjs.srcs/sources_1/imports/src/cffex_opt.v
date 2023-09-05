// --------------------------------------------------------------------------------
// (c) Copyright 2017-2020 Meridian Technologies. All rights reserved.
//
// Tool Version: Vivado 2018.3
// Design      : cffex_opt.v
// Author      : liuchaofan
// Called by   :
// Description : ht_cffex_opt top module
// Date        : 2020-07-04
// Verson      : 1.0
// --------------------------------------------------------------------------------
// Verson Description
// 1.00   2020-07-04       The initial verson
// --------------------------------------------------------------------------------
module cffex_opt #(
    parameter         NUM_PORTS = 2,
	parameter [31:0]  SYNTH_DATECODE=0
    )
    (
    input  wire                         clk_net           ,
    input  wire                         clk_host          ,
    input  wire                         rst_n             ,
    input  wire [31:0]                  hw_time_host      ,
    input  wire [31:0]                  hw_time_net       ,

    output wire [64*NUM_PORTS-1:0]      rx_data_host      ,
    output wire [3*NUM_PORTS-1:0]       rx_len_host       ,
    output wire [NUM_PORTS-1:0]         rx_vld_host       ,
    output wire [NUM_PORTS-1:0]         rx_sof_host       ,
    output wire [NUM_PORTS-1:0]         rx_eof_host       ,
    output wire [NUM_PORTS-1:0]         rx_err_host       ,
    output wire [NUM_PORTS-1:0]         rx_crc_fail_host  ,
    output wire [32*NUM_PORTS-1:0]      rx_timestamp_host ,
    output wire [8*NUM_PORTS-1:0]       rx_match_host     ,
    output wire [6*NUM_PORTS-1:0]       rx_buffer_host    ,

    input  wire [64*NUM_PORTS-1:0]      tx_data_host      ,
    input  wire [3*NUM_PORTS-1:0]       tx_len_host       ,
    input  wire [NUM_PORTS-1:0]         tx_vld_host       ,
    input  wire [NUM_PORTS-1:0]         tx_sof_host       ,
    input  wire [NUM_PORTS-1:0]         tx_eof_host       ,
    output wire [NUM_PORTS-1:0]         tx_ack_host       ,

    input  wire [64*NUM_PORTS-1:0]      rx_data_net       ,
    input  wire [3*NUM_PORTS-1:0]       rx_len_net        ,
    input  wire [NUM_PORTS-1:0]         rx_sof_net        ,
    input  wire [NUM_PORTS-1:0]         rx_eof_net        ,
    input  wire [NUM_PORTS-1:0]         rx_vld_net        ,
    input  wire [NUM_PORTS-1:0]         rx_crc_fail_net   ,
    input  wire [NUM_PORTS-1:0]         rx_err_net        ,
    input  wire [32*NUM_PORTS-1:0]      rx_timestamp_net  ,

    output wire [64*NUM_PORTS-1:0]      tx_data_net       ,
    output wire [3*NUM_PORTS-1:0]       tx_len_net        ,
    output wire [NUM_PORTS-1:0]         tx_sof_net        ,
    output wire [NUM_PORTS-1:0]         tx_eof_net        ,
    output wire [NUM_PORTS-1:0]         tx_vld_net        ,
    input  wire [NUM_PORTS-1:0]         tx_ack_net        ,

    input  wire                         reg_w_en          ,
    input  wire [10:0]                  reg_w_addr        ,
    input  wire [31:0]                  reg_w_data        ,
    input  wire [10:0]                  reg_r_addr        ,
    input  wire                         reg_r_en          ,
    output wire [31:0]                  reg_r_data        ,
    output wire                         reg_r_ack
    );

//parameter declare
parameter VERSION_DATE = 32'h2020_0808;
parameter VERSION_NUM = 32'h0001_0000;

//signal declare
wire         s_soft_reset;
wire [7:0]   s_net_fifo_rd_thresh;
wire [31:0]  s_net_rx_cnt;
wire [31:0]  s_net_rx_err_cnt;
wire [31:0]  s_md_rx_cnt;
wire [31:0]  s_md_drop_cnt;
wire [31:0]  s_md_tx_cnt;
wire [31:0]  s_sn_reg;
wire [31:0]  s_sn_discont_cnt;
wire [31:0]  s_net_fifo_full_cnt;
wire [31:0]  s_net_tx_cnt;
wire [31:0]  s_net_ack_low_cnt;
wire [31:0]  s_dma_tx_cnt;

//register module
cffex_reg #(
    .VERSION_DATE         ( VERSION_DATE              ),
    .VERSION_NUM          ( VERSION_NUM               )
    )
    u_cffex_reg(
    .i_clk_net            ( clk_net                   ),
    .i_clk_host           ( clk_host                  ),
    .i_rst_n              ( rst_n                     ),
    //register interface
    .i_reg_w_en           ( reg_w_en                  ),
    .i_reg_w_addr         ( reg_w_addr[10:0]          ),
    .i_reg_w_data         ( reg_w_data[31:0]          ),
    .i_reg_r_addr         ( reg_r_addr[10:0]          ),
    .i_reg_r_en           ( reg_r_en                  ),
    .o_reg_r_data         ( reg_r_data[31:0]          ),
    .o_reg_r_ack          ( reg_r_ack                 ),
    //reg
    .o_soft_reset         ( s_soft_reset              ),
    .o_net_fifo_rd_thresh ( s_net_fifo_rd_thresh[7:0] ),
    .i_net_rx_cnt         ( s_net_rx_cnt[31:0]        ),
    .i_net_rx_err_cnt     ( s_net_rx_err_cnt[31:0]    ),
    .i_md_rx_cnt          ( s_md_rx_cnt[31:0]         ),
    .i_md_drop_cnt        ( s_md_drop_cnt[31:0]       ),
    .i_md_tx_cnt          ( s_md_tx_cnt[31:0]         ),
    .i_sn_reg             ( s_sn_reg[31:0]            ),
    .i_sn_discont_cnt     ( s_sn_discont_cnt[31:0]    ),
    .i_net_fifo_full_cnt  ( s_net_fifo_full_cnt[31:0] ),
    .i_net_tx_cnt         ( s_net_tx_cnt[31:0]        ),
    .i_net_ack_low_cnt    ( s_net_ack_low_cnt[31:0]   ),
    .i_dma_tx_cnt         ( s_dma_tx_cnt[31:0]        )

    );

//filter
md_filter #(
    .ETH_TYPE_EN          (  1'b1                     ),
    .ETH_TYPE             ( 16'h0800                  ),
    .PROTOCOL_EN          (  1'b1                     ),
    .PROTOCOL             (  8'h11                    ),
    .TID                  ( 32'h00005902              )
    )
    u_md_filter
    (
    //clks & resets
    .i_clk_net            ( clk_net                   ),
    .i_clk_host           ( clk_host                  ),
    .i_rst_n              ( rst_n                     ),
    .i_soft_reset         ( s_soft_reset              ),
    //input net port
    .i_rx_data_net        ( rx_data_net[127:64]         ),
    .i_rx_len_net         ( rx_len_net[5:3]           ),
    .i_rx_sof_net         ( rx_sof_net[1]             ),
    .i_rx_eof_net         ( rx_eof_net[1]             ),
    .i_rx_vld_net         ( rx_vld_net[1]             ),
    .i_rx_crc_fail_net    ( rx_crc_fail_net[1]        ),
    .i_rx_err_net         ( rx_err_net[1]             ),
    .i_rx_timestamp_net   ( rx_timestamp_net[63:32]    ),
    //output net port
    .o_tx_data_net        ( tx_data_net[127:64]       ),
    .o_tx_len_net         ( tx_len_net[5:3]           ),
    .o_tx_sof_net         ( tx_sof_net[1]             ),
    .o_tx_eof_net         ( tx_eof_net[1]             ),
    .o_tx_vld_net         ( tx_vld_net[1]             ),
    .i_tx_ack_net         ( tx_ack_net[1]             ),
    //output dma port
    .o_tx_data_host       ( rx_data_host[127:64]      ),
    .o_tx_len_host        ( rx_len_host[5:3]          ),
    .o_tx_vld_host        ( rx_vld_host[1]            ),
    .o_tx_sof_host        ( rx_sof_host[1]            ),
    .o_tx_eof_host        ( rx_eof_host[1]            ),
    .o_tx_err_host        ( rx_err_host[1]            ),
    .o_tx_crc_fail_host   ( rx_crc_fail_host[1]       ),
    .o_tx_timestamp_host  ( rx_timestamp_host[63:32]  ),
    .o_tx_match_host      ( rx_match_host[15:8]       ),
    .o_tx_buffer_host     ( rx_buffer_host[11:6]      ),
    //stats
    .i_net_fifo_rd_thresh ( s_net_fifo_rd_thresh[7:0] ),
    .o_net_rx_cnt         ( s_net_rx_cnt[31:0]        ),
    .o_net_rx_err_cnt     ( s_net_rx_err_cnt[31:0]    ),
    .o_md_rx_cnt          ( s_md_rx_cnt[31:0]         ),
    .o_md_drop_cnt        ( s_md_drop_cnt[31:0]       ),
    .o_md_tx_cnt          ( s_md_tx_cnt[31:0]         ),
    .o_sn_reg             ( s_sn_reg[31:0]            ),
    .o_sn_discont_cnt     ( s_sn_discont_cnt[31:0]    ),
    .o_net_fifo_full_cnt  ( s_net_fifo_full_cnt[31:0] ),
    .o_net_tx_cnt         ( s_net_tx_cnt[31:0]        ),
    .o_net_ack_low_cnt    ( s_net_ack_low_cnt[31:0]   ),
    .o_dma_tx_cnt         ( s_dma_tx_cnt[31:0]        )

    );

//port 0: nic function in dual direction
nic u_port0_nic_rx (
    .i_clk_net           ( clk_net                  ),
    .i_clk_host          ( clk_host                 ),
    .i_rst_n             ( rst_n                    ),

    .o_rx_data_host      ( rx_data_host[63:0]       ),
    .o_rx_len_host       ( rx_len_host[2:0]         ),
    .o_rx_vld_host       ( rx_vld_host[0]           ),
    .o_rx_sof_host       ( rx_sof_host[0]           ),
    .o_rx_eof_host       ( rx_eof_host[0]           ),
    .o_rx_err_host       ( rx_err_host[0]           ),
    .o_rx_crc_fail_host  ( rx_crc_fail_host[0]      ),
    .o_rx_timestamp_host ( rx_timestamp_host[31:0]  ),
    .o_rx_match_host     ( rx_match_host[7:0]       ),
    .o_rx_buffer_host    ( rx_buffer_host[5:0]      ),

    .i_tx_data_host      (                          ),
    .i_tx_len_host       (                          ),
    .i_tx_vld_host       (                          ),
    .i_tx_sof_host       (                          ),
    .i_tx_eof_host       (                          ),
    .o_tx_ack_host       (                          ),

    .i_rx_data_net       ( rx_data_net[63:0]        ),
    .i_rx_len_net        ( rx_len_net[2:0]          ),
    .i_rx_sof_net        ( rx_sof_net[0]            ),
    .i_rx_eof_net        ( rx_eof_net[0]            ),
    .i_rx_vld_net        ( rx_vld_net[0]            ),
    .i_rx_crc_fail_net   ( rx_crc_fail_net[0]       ),
    .i_rx_err_net        ( rx_err_net[0]            ),
    .i_rx_timestamp_net  ( rx_timestamp_net[31:0]   ),

    .o_tx_data_net       (                          ),
    .o_tx_len_net        (                          ),
    .o_tx_sof_net        (                          ),
    .o_tx_eof_net        (                          ),
    .o_tx_vld_net        (                          ),
    .i_tx_ack_net        (                          )

    );
////port 1: nic function in dual direction
//nic u_port1_nic_rx (
//    .i_clk_net           ( clk_net                  ),
//    .i_clk_host          ( clk_host                 ),
//    .i_rst_n             ( rst_n                    ),
//
//    .o_rx_data_host      ( rx_data_host[127:64]     ),
//    .o_rx_len_host       ( rx_len_host[5:3]         ),
//    .o_rx_vld_host       ( rx_vld_host[1]           ),
//    .o_rx_sof_host       ( rx_sof_host[1]           ),
//    .o_rx_eof_host       ( rx_eof_host[1]           ),
//    .o_rx_err_host       ( rx_err_host[1]           ),
//    .o_rx_crc_fail_host  ( rx_crc_fail_host[1]      ),
//    .o_rx_timestamp_host ( rx_timestamp_host[63:32] ),
//    .o_rx_match_host     ( rx_match_host[15:8]      ),
//    .o_rx_buffer_host    ( rx_buffer_host[11:6]     ),
//
//    .i_tx_data_host      ( tx_data_host[127:64]     ),
//    .i_tx_len_host       ( tx_len_host[5:3]         ),
//    .i_tx_vld_host       ( tx_vld_host[1]           ),
//    .i_tx_sof_host       ( tx_sof_host[1]           ),
//    .i_tx_eof_host       ( tx_eof_host[1]           ),
//    .o_tx_ack_host       ( tx_ack_host[1]           ),
//
//    .i_rx_data_net       ( rx_data_net[127:64]      ),
//    .i_rx_len_net        ( rx_len_net[5:3]          ),
//    .i_rx_sof_net        ( rx_sof_net[1]            ),
//    .i_rx_eof_net        ( rx_eof_net[1]            ),
//    .i_rx_vld_net        ( rx_vld_net[1]            ),
//    .i_rx_crc_fail_net   ( rx_crc_fail_net[1]       ),
//    .i_rx_err_net        ( rx_err_net[1]            ),
//    .i_rx_timestamp_net  ( rx_timestamp_net[63:32]  ),
//
//    .o_tx_data_net       ( tx_data_net[127:64]      ),
//    .o_tx_len_net        ( tx_len_net[5:3]          ),
//    .o_tx_sof_net        ( tx_sof_net[1]            ),
//    .o_tx_eof_net        ( tx_eof_net[1]            ),
//    .o_tx_vld_net        ( tx_vld_net[1]            ),
//    .i_tx_ack_net        ( tx_ack_net[1]            )
//
//    );

//0
//rx_data_host[63:0]           tx_data_host[63:0]      rx_data_net[63:0]          tx_data_net[63:0]
//rx_len_host[2:0]             tx_len_host[2:0]        rx_len_net[2:0]            tx_len_net[2:0]
//rx_vld_host[0]               tx_vld_host[0]          rx_sof_net[0]              tx_sof_net[0]
//rx_sof_host[0]               tx_sof_host[0]          rx_eof_net[0]              tx_eof_net[0]
//rx_eof_host[0]               tx_eof_host[0]          rx_vld_net[0]              tx_vld_net[0]
//rx_err_host[0]               tx_ack_host[0]          rx_crc_fail_net[0]         tx_ack_net[0]
//rx_crc_fail_host[0]                                  rx_err_net[0]
//rx_timestamp_host[31:0]                              rx_timestamp_net[31:0]
//rx_match_host[7:0]
//rx_buffer_host[5:0]
//
//1
//rx_data_host[127:64]         tx_data_host[127:64]    rx_data_net[127:64]        tx_data_net[127:64]
//rx_len_host[5:3]             tx_len_host[5:3]        rx_len_net[5:3]            tx_len_net[5:3]
//rx_vld_host[1]               tx_vld_host[1]          rx_sof_net[1]              tx_sof_net[1]
//rx_sof_host[1]               tx_sof_host[1]          rx_eof_net[1]              tx_eof_net[1]
//rx_eof_host[1]               tx_eof_host[1]          rx_vld_net[1]              tx_vld_net[1]
//rx_err_host[1]               tx_ack_host[1]          rx_crc_fail_net[1]         tx_ack_net[1]
//rx_crc_fail_host[1]                                  rx_err_net[1]
//rx_timestamp_host[63:32]                             rx_timestamp_net[63:32]
//rx_match_host[15:8]
//rx_buffer_host[11:6]



endmodule
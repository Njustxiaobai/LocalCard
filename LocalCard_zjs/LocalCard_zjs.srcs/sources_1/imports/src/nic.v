// --------------------------------------------------------------------------------
// (c) Copyright 2017-2020 Meridian Technologies. All rights reserved.
//
// Tool Version: Vivado 2018.3
// Design      : nic.v
// Author      : liuchaofan
// Called by   : cffex_opt.v
// Description : nic module for one port in dual-direction
// Date        : 2020-07-22
// Verson      : 1.0
// --------------------------------------------------------------------------------
// Verson Description
// 1.00   2020-07-22       The initial verson
// --------------------------------------------------------------------------------

module nic #(
    parameter         NUM_PORTS = 1
    )
    (
    input  wire                         i_clk_net           ,
    input  wire                         i_clk_host          ,
    input  wire                         i_rst_n             ,

    output wire [64*NUM_PORTS-1:0]      o_rx_data_host      ,
    output wire [3*NUM_PORTS-1:0]       o_rx_len_host       ,
    output wire [NUM_PORTS-1:0]         o_rx_vld_host       ,
    output wire [NUM_PORTS-1:0]         o_rx_sof_host       ,
    output wire [NUM_PORTS-1:0]         o_rx_eof_host       ,
    output wire [NUM_PORTS-1:0]         o_rx_err_host       ,
    output wire [NUM_PORTS-1:0]         o_rx_crc_fail_host  ,
    output wire [32*NUM_PORTS-1:0]      o_rx_timestamp_host ,
    output wire [8*NUM_PORTS-1:0]       o_rx_match_host     ,
    output wire [6*NUM_PORTS-1:0]       o_rx_buffer_host    ,

    input  wire [64*NUM_PORTS-1:0]      i_tx_data_host      ,
    input  wire [3*NUM_PORTS-1:0]       i_tx_len_host       ,
    input  wire [NUM_PORTS-1:0]         i_tx_vld_host       ,
    input  wire [NUM_PORTS-1:0]         i_tx_sof_host       ,
    input  wire [NUM_PORTS-1:0]         i_tx_eof_host       ,
    output wire [NUM_PORTS-1:0]         o_tx_ack_host       ,

    (* mark_debug="true" *)
    input  wire [64*NUM_PORTS-1:0]      i_rx_data_net       ,
    (* mark_debug="true" *)
    input  wire [3*NUM_PORTS-1:0]       i_rx_len_net        ,
    (* mark_debug="true" *)
    input  wire [NUM_PORTS-1:0]         i_rx_sof_net        ,
    (* mark_debug="true" *)
    input  wire [NUM_PORTS-1:0]         i_rx_eof_net        ,
    (* mark_debug="true" *)
    input  wire [NUM_PORTS-1:0]         i_rx_vld_net        ,
    input  wire [NUM_PORTS-1:0]         i_rx_crc_fail_net   ,
    input  wire [NUM_PORTS-1:0]         i_rx_err_net        ,
    input  wire [32*NUM_PORTS-1:0]      i_rx_timestamp_net  ,

    output wire [64*NUM_PORTS-1:0]      o_tx_data_net       ,
    output wire [3*NUM_PORTS-1:0]       o_tx_len_net        ,
    output wire [NUM_PORTS-1:0]         o_tx_sof_net        ,
    output wire [NUM_PORTS-1:0]         o_tx_eof_net        ,
    output wire [NUM_PORTS-1:0]         o_tx_vld_net        ,
    input  wire [NUM_PORTS-1:0]         i_tx_ack_net

    );

//nic function from net to host
wire s_rx_sof_rx0;
wire s_fifo_valid_rx0;

async_fifo #(
    .WIDTH(64 + 3 + 1 + 1 + 1 + 1)
    )
    async_fifo_inst_rx0
    (
    .clk_write(i_clk_net),
    .data_in({i_rx_sof_net[0], i_rx_eof_net[0], i_rx_err_net[0], i_rx_len_net[2:0], i_rx_data_net[63:0], i_rx_crc_fail_net[0]}),
    .wren(i_rx_vld_net[0]),

    .clk_read(i_clk_host),
    .data_out({s_rx_sof_rx0, o_rx_eof_host[0], o_rx_err_host[0], o_rx_len_host[2:0], o_rx_data_host[63:0], o_rx_crc_fail_host[0]}),
    .vld(s_fifo_valid_rx0),
    .rden(1'b1)
    );

assign o_rx_sof_host[0] = s_rx_sof_rx0 & s_fifo_valid_rx0;
assign o_rx_vld_host[0] = s_fifo_valid_rx0;
assign o_rx_timestamp_host[31:0] = i_rx_timestamp_net[31:0];
assign o_rx_match_host[7:0] = 8'b0;
assign o_rx_buffer_host[5:0] = 6'b0;


//nic function from host to net
wire s_fifo_full_tx0;
wire s_tx_sof_net_tx0;
wire s_fifo_valid_tx0;

async_fifo #(
    .WIDTH(64 + 3 + 1 + 1)
    )
    async_fifo_inst_tx0
    (
    .clk_write(i_clk_host),
    .data_in({i_tx_sof_host[0], i_tx_eof_host[0], i_tx_len_host[2:0], i_tx_data_host[63:0]}),
    .wren(i_tx_vld_host[0]),
    .full(s_fifo_full_tx0),

    .clk_read(i_clk_net),
    .data_out({s_tx_sof_net_tx0, o_tx_eof_net[0], o_tx_len_net[2:0], o_tx_data_net[63:0]}),
    .vld(s_fifo_valid_tx0),
    .rden(i_tx_ack_net[0]),
    .almost_empty()
    );

assign o_tx_ack_host[0] = !s_fifo_full_tx0;
assign o_tx_sof_net[0] = s_tx_sof_net_tx0 & s_fifo_valid_tx0;
assign o_tx_vld_net[0] = s_fifo_valid_tx0;



//debug
(* mark_debug="true" *)
reg          data_repeat = 1'b0;
reg  [63:0]  s_rx_data_net = 'd0;

always @(posedge i_clk_net)
begin
    if(i_rx_vld_net == 1'b1)begin
        s_rx_data_net <= i_rx_data_net;
    end
    else;
end

always @(posedge i_clk_net)
begin
    if(i_rx_vld_net == 1'b1 && ((i_rx_data_net[63:32] == i_rx_data_net[31:0]) || (i_rx_data_net[31:0] == s_rx_data_net[63:32])))
        data_repeat <= 1'b1;
    else
        data_repeat <= 1'b0;
end



endmodule
// --------------------------------------------------------------------------------
// (c) Copyright 2017-2020 Meridian Technologies. All rights reserved.
//
// Tool Version: Vivado 2018.3
// Design      : md_filter.v
// Author      : liuchaofan
// Called by   : cffex_opt.v
// Description : multi-udp filter module
// Date        : 2020-07-17
// Verson      : 1.0
// --------------------------------------------------------------------------------
// Verson Description3
// 1.00   2020-07-17       The initial verson
// 1.01   2020-08-05       add net_tx & host_tx
// --------------------------------------------------------------------------------
module md_filter #(
    parameter           ETH_TYPE_EN          =  1'b1        ,
    parameter           ETH_TYPE             = 16'h0800     ,
    parameter           PROTOCOL_EN          =  1'b1        ,
    parameter           PROTOCOL             =  8'h11       ,
    parameter           TID                  = 32'h00005902
    )
    (
    //clks & resets
    input  wire         i_clk_net                           ,
    input  wire         i_clk_host                          ,
    input  wire         i_rst_n                             ,
    input  wire         i_soft_reset                        ,
    //input net port
    (* mark_debug="true" *)
    input  wire [63:0]  i_rx_data_net                       ,
    (* mark_debug="true" *)
    input  wire [2:0]   i_rx_len_net                        ,
    (* mark_debug="true" *)
    input  wire         i_rx_sof_net                        ,
    (* mark_debug="true" *)
    input  wire         i_rx_eof_net                        ,
    (* mark_debug="true" *)
    input  wire         i_rx_vld_net                        ,
    input  wire         i_rx_crc_fail_net                   ,
    input  wire         i_rx_err_net                        ,
    input  wire [31:0]  i_rx_timestamp_net                  ,
    //output net port
    (* mark_debug="true" *)
    output wire [63:0]  o_tx_data_net                       ,
    (* mark_debug="true" *)
    output wire [2:0]   o_tx_len_net                        ,
    (* mark_debug="true" *)
    output wire         o_tx_sof_net                        ,
    (* mark_debug="true" *)
    output wire         o_tx_eof_net                        ,
    (* mark_debug="true" *)
    output wire         o_tx_vld_net                        ,
    (* mark_debug="true" *)
    input  wire         i_tx_ack_net                        ,
    //output dma port
    output wire [63:0]  o_tx_data_host                      ,
    output wire [2:0]   o_tx_len_host                       ,
    output wire         o_tx_vld_host                       ,
    output wire         o_tx_sof_host                       ,
    output wire         o_tx_eof_host                       ,
    output wire         o_tx_err_host                       ,
    output wire         o_tx_crc_fail_host                  ,
    output wire [31:0]  o_tx_timestamp_host                 ,
    output wire [7:0]   o_tx_match_host                     ,
    output wire [5:0]   o_tx_buffer_host                    ,
    //reg & stat
    input  wire [7:0]   i_net_fifo_rd_thresh                ,
    output reg  [31:0]  o_net_rx_cnt         = 'd0          ,
    output reg  [31:0]  o_net_rx_err_cnt     = 'd0          ,
    output reg  [31:0]  o_md_rx_cnt          = 'd0          ,
    output reg  [31:0]  o_md_drop_cnt        = 'd0          ,
    output reg  [31:0]  o_md_tx_cnt          = 'd0          ,
    output reg  [31:0]  o_sn_reg             = 'b0          ,
    output reg  [31:0]  o_sn_discont_cnt     = 'd0          ,
    output reg  [31:0]  o_net_fifo_full_cnt  = 'd0          ,
    output reg  [31:0]  o_net_tx_cnt         = 'd0          ,
    output reg  [31:0]  o_net_ack_low_cnt    = 'd0          ,
    output reg  [31:0]  o_dma_tx_cnt         = 'd0

    );

//signal declare
//udp filter signals
reg  [103:0] s_pkt_header = 'b0;
reg  [103:0] s_pkt_header_d1 = 'b0;
reg  [103:0] s_net_rx_data = 'b0;
reg  [103:0] s_net_rx_data_d1 = 'b0;
reg  [103:0] s_net_rx_data_d2 = 'b0;
reg  [103:0] s_net_rx_data_d3 = 'b0;
reg  [103:0] s_net_rx_data_d4 = 'b0;
reg  [103:0] s_net_rx_data_d5 = 'b0;
reg  [103:0] s_net_rx_data_d6 = 'b0;
reg  [103:0] s_net_rx_data_d7 = 'b0;
reg  [103:0] s_net_rx_data_d8 = 'b0;
reg  [103:0] s_net_rx_data_d9 = 'b0;
reg          s_net_rx_sof_flag = 1'b0;
reg  [7:0]   s_rx_pkt_cnt = 'd0;
reg  [7:0]   s_rx_pkt_cnt_d1 = 'd0;
wire [15:0]  s_eth_type;
(* mark_debug="true" *)
reg          s_eth_type_match = 1'b0;
wire [7:0]   s_protocol;
(* mark_debug="true" *)
reg          s_protocol_match = 1'b0;
wire [31:0]  s_tid;
(* mark_debug="true" *)
reg          s_tid_match = 1'b0;
wire [31:0]  s_sn;
(* mark_debug="true" *)
reg          s_sn_new = 1'b0;
reg  [31:0]  s_sn_reg = 'b0;
reg  [31:0]  s_sn_reg_d1 = 'b0;
(* mark_debug="true" *)
reg          s_sn_discont = 1'b0;
reg  [31:0]  s_sn_discont_cnt = 'b0;
reg  [31:0]  s_sn_discont_cnt_d1 = 'b0;
(* mark_debug="true" *)
reg          s_pass_valid = 1'b0;
reg  [31:0]  s_net_rx_cnt = 'd0;
reg  [31:0]  s_net_rx_cnt_d1 = 'd0;
reg  [31:0]  s_net_rx_err_cnt = 'd0;
reg  [31:0]  s_net_rx_err_cnt_d1 = 'd0;
reg  [31:0]  s_md_rx_cnt = 'd0;
reg  [31:0]  s_md_rx_cnt_d1 = 'd0;
reg  [31:0]  s_md_drop_cnt = 'd0;
reg  [31:0]  s_md_drop_cnt_d1 = 'd0;
reg          s_md_tx_sof_flag;
reg  [31:0]  s_md_tx_cnt = 'd0;
reg  [31:0]  s_md_tx_cnt_d1 = 'd0;
(* mark_debug="true" *)
reg  [63:0]  s_md_tx_data_net ='b0;
(* mark_debug="true" *)
reg  [2:0]   s_md_tx_len_net = 'b0;
(* mark_debug="true" *)
reg          s_md_tx_sof_net = 1'b0;
(* mark_debug="true" *)
reg          s_md_tx_eof_net = 1'b0;
(* mark_debug="true" *)
reg          s_md_tx_vld_net = 1'b0;
reg          s_md_tx_crc_fail_net = 1'b0;
reg          s_md_tx_err_net = 1'b0;
reg  [31:0]  s_md_tx_timestamp_net = 'b0;

//net tx signals
wire [68:0]  s_net_fifo_data_in;
(* mark_debug="true" *)
wire         s_net_fifo_full;
wire [68:0]  s_net_fifo_data_out;
(* mark_debug="true" *)
wire         s_net_fifo_valid;
(* mark_debug="true" *)
reg          s_net_fifo_buf_rden = 1'b0;
(* mark_debug="true" *)
wire         s_net_fifo_rden;
(* mark_debug="true" *)
wire         s_net_fifo_almost_empty;
reg  [7:0]   s_md_tx_pkt_cnt = 'd0;
reg  [7:0]   s_md_tx_pkt_cnt_d1 = 'd0;
reg          s_net_tx_sof_flag = 1'b0;
reg  [31:0]  s_net_fifo_full_cnt = 'd0;
reg  [31:0]  s_net_fifo_full_cnt_d1 = 'd0;
reg  [31:0]  s_net_tx_cnt = 'd0;
reg  [31:0]  s_net_tx_cnt_d1 = 'd0;
reg  [31:0]  s_net_ack_low_cnt = 'd0;
reg  [31:0]  s_net_ack_low_cnt_d1 = 'd0;

//dma tx signals
wire [70:0]  s_dma_fifo_data_in;
(* mark_debug="true" *)
wire         s_dma_fifo_full;
wire [70:0]  s_dma_fifo_data_out;
(* mark_debug="true" *)
wire         s_dma_fifo_valid;
(* mark_debug="true" *)
wire         s_dma_fifo_almost_empty;
reg          s_dma_tx_sof_flag;


//-----------------------------------------------------------
// 1. udp filter process
//-----------------------------------------------------------

//1.1. input data process
//pkt header group
always @ (posedge i_clk_net)
begin
    if(i_rx_vld_net == 1'b1) begin
        s_pkt_header <= {i_rx_timestamp_net[31:0], //bit 103:72
                         i_rx_err_net,             //bit 71
                         i_rx_crc_fail_net,        //bit 70
                         i_rx_len_net[2:0],        //bit 69:67
                         i_rx_vld_net,             //bit 66
                         i_rx_eof_net,             //bit 65
                         i_rx_sof_net,             //bit 64
                         i_rx_data_net[63:0]};     //bit 63:0
    end
    else;
end

//header delay
always @ (posedge i_clk_net)
begin
    if(i_rx_vld_net == 1'b1)
        s_pkt_header_d1 <= s_pkt_header;
    else;
end

//input direct pipeline
always @ (posedge i_clk_net)
begin
    s_net_rx_data <= {i_rx_timestamp_net[31:0], //bit 103:72
                      i_rx_err_net,             //bit 71
                      i_rx_crc_fail_net,        //bit 70
                      i_rx_len_net[2:0],        //bit 69:67
                      i_rx_vld_net,             //bit 66
                      i_rx_eof_net,             //bit 65
                      i_rx_sof_net,             //bit 64
                      i_rx_data_net[63:0]};     //bit 63:0
end

always @ (posedge i_clk_net)
begin
    s_net_rx_data_d1 <= s_net_rx_data;
    s_net_rx_data_d2 <= s_net_rx_data_d1;
    s_net_rx_data_d3 <= s_net_rx_data_d2;
    s_net_rx_data_d4 <= s_net_rx_data_d3;
    s_net_rx_data_d5 <= s_net_rx_data_d4;
    s_net_rx_data_d6 <= s_net_rx_data_d5;
    s_net_rx_data_d7 <= s_net_rx_data_d6;
    s_net_rx_data_d8 <= s_net_rx_data_d7;
    s_net_rx_data_d9 <= s_net_rx_data_d8;
end

//rx sof flag
always @ (posedge i_clk_net)
begin
    if(i_rx_vld_net == 1'b1 && i_rx_eof_net)
        s_net_rx_sof_flag <= 1'b0;
    else if(i_rx_vld_net == 1'b1 && i_rx_sof_net)
        s_net_rx_sof_flag <= 1'b1;
    else;
end

//rx pkt counter from sof
always @ (posedge i_clk_net)
begin
    if(i_rx_vld_net == 1'b1 && i_rx_eof_net)
        s_rx_pkt_cnt <= 'd0;
    else if(i_rx_vld_net == 1'b1 && i_rx_sof_net)
        s_rx_pkt_cnt <= 'd1;
    else if(s_net_rx_sof_flag == 1'b1 && i_rx_vld_net == 1'b1 && s_rx_pkt_cnt != 'd255)
        s_rx_pkt_cnt <= s_rx_pkt_cnt + 'd1;
    else;
end

always @ (posedge i_clk_net)
begin
    s_rx_pkt_cnt_d1 <= s_rx_pkt_cnt;
end

//1.2. field update & match
//eth_type
assign s_eth_type = {s_pkt_header[39:32], s_pkt_header[47:40]};

always @ (posedge i_clk_net)
begin
    if(s_rx_pkt_cnt == 'd2)begin
        if(ETH_TYPE_EN == 1'b0)
            s_eth_type_match <= 1'b1;
        else if(s_eth_type == ETH_TYPE)
            s_eth_type_match <= 1'b1;
        else
            s_eth_type_match <= 1'b0;
    end
    else;
end

//protocol
assign s_protocol = s_pkt_header[63:56];

always @ (posedge i_clk_net)
begin
    if(s_rx_pkt_cnt == 'd3)begin
        if(PROTOCOL_EN == 1'b0)
            s_protocol_match <= 1'b1;
        else if(s_protocol == PROTOCOL)
            s_protocol_match <= 1'b1;
        else
            s_protocol_match <= 1'b0;
    end
    else;
end

//tid
assign s_tid = {s_pkt_header_d1[55:48], s_pkt_header_d1[63:56], s_pkt_header[7:0], s_pkt_header[15:8]};

//sn
assign s_sn = {s_pkt_header[23:16], s_pkt_header[31:24], s_pkt_header[39:32], s_pkt_header[47:40]};

//sn compare
always @ (posedge i_clk_net)
begin
    if(i_soft_reset == 1'b1) begin
        s_sn_new <= 1'b0;
        s_sn_reg <= 'b0;
    end
    else if(s_rx_pkt_cnt == 'd7 && s_rx_pkt_cnt_d1 == 'd6) begin
        if(s_eth_type_match == 1'b1 && s_protocol_match == 1'b1 && s_tid == TID && s_sn > s_sn_reg)begin
            s_sn_new <= 1'b1;
            s_sn_reg <= s_sn;
        end
        else begin
            s_sn_new <= 1'b0;
            s_sn_reg <= s_sn_reg;
        end
    end
    else;
end

//sn discont cnt
always @ (posedge i_clk_net)
begin
    if(i_soft_reset == 1'b1) begin
        s_sn_discont     <= 1'b0;
        s_sn_discont_cnt <= 'd0;
    end
    else if(s_rx_pkt_cnt == 'd7 && s_rx_pkt_cnt_d1 == 'd6 && s_eth_type_match == 1'b1 && s_protocol_match == 1'b1 && s_tid == TID) begin
        if((s_sn > s_sn_reg) && (s_sn - s_sn_reg > 1))begin
            s_sn_discont     <= 1'b1;
            s_sn_discont_cnt <= s_sn_discont_cnt + 'd1;
        end
        else begin
            s_sn_discont     <= 1'b0;
            s_sn_discont_cnt <= s_sn_discont_cnt;
        end
    end
    else;
end

//pass filter
always @ (posedge i_clk_net)
begin
    if(s_rx_pkt_cnt == 'd8 && s_rx_pkt_cnt_d1 == 'd7 && s_pkt_header[66] == 1'b1)
        s_pass_valid <= s_sn_new;
    else;
end

//1.3. filter stat
//input net cnt
always @ (posedge i_clk_net)
begin
    if(i_soft_reset == 1'b1)
        s_net_rx_cnt <= 'd0;
    else if(s_net_rx_sof_flag == 1'b1 && i_rx_vld_net == 1'b1 && i_rx_eof_net == 1'b1)
        s_net_rx_cnt <= s_net_rx_cnt + 'd1;
    else;
end

//input net err cnt
always @ (posedge i_clk_net)
begin
    if(i_soft_reset == 1'b1)
        s_net_rx_err_cnt <= 'd0;
    else if(i_rx_vld_net == 1'b1 && (i_rx_crc_fail_net == 1'b1 || i_rx_err_net == 1'b1))
        s_net_rx_err_cnt <= s_net_rx_err_cnt + 'd1;
    else;
end

//input md cnt & drop cnt
always @ (posedge i_clk_net)
begin
    if(i_soft_reset == 1'b1) begin
        s_md_rx_cnt   <= 'd0;
        s_md_drop_cnt <= 'd0;
    end
    else if(s_rx_pkt_cnt == 'd7 && s_rx_pkt_cnt_d1 == 'd6 && s_eth_type_match == 1'b1 && s_protocol_match == 1'b1 && s_tid == TID)begin
        if(s_sn > s_sn_reg)begin
            s_md_rx_cnt   <= s_md_rx_cnt + 'd1;
            s_md_drop_cnt <= s_md_drop_cnt;
        end
        else begin
            s_md_rx_cnt   <= s_md_rx_cnt + 'd1;
            s_md_drop_cnt <= s_md_drop_cnt + 'd1;
        end
    end
    else;
end

//filter output md sof flag
always @ (posedge i_clk_net)
begin
    if(s_md_tx_vld_net == 1'b1 && s_md_tx_eof_net == 1'b1)
        s_md_tx_sof_flag <= 1'b0;
    else if(s_md_tx_vld_net == 1'b1 && s_md_tx_sof_net == 1'b1)
        s_md_tx_sof_flag <= 1'b1;
    else;
end

//filter output md tx cnt
always @ (posedge i_clk_net)
begin
    if(i_soft_reset == 1'b1)
        s_md_tx_cnt <= 'd0;
    else if(s_md_tx_sof_flag == 1'b1 && s_md_tx_vld_net == 1'b1 && s_md_tx_eof_net == 1'b1)
        s_md_tx_cnt <= s_md_tx_cnt + 'd1;
    else;
end

//1.4. filter md tx
always @ (posedge i_clk_net)
begin
    s_md_tx_data_net      <= s_net_rx_data_d9[63:0];
    s_md_tx_len_net       <= s_net_rx_data_d9[69:67];
    s_md_tx_sof_net       <= s_net_rx_data_d9[64];
    s_md_tx_eof_net       <= s_net_rx_data_d9[65];
    s_md_tx_crc_fail_net  <= s_net_rx_data_d9[70];
    s_md_tx_err_net       <= s_net_rx_data_d9[71];
    s_md_tx_timestamp_net <= s_net_rx_data_d9[103:72];
end

always @ (posedge i_clk_net)
begin
    s_md_tx_vld_net <= s_net_rx_data_d9[66] & s_pass_valid;
end


//-----------------------------------------------------------
// 2. output net port
//-----------------------------------------------------------

//net fifo data input
assign s_net_fifo_data_in = {s_md_tx_sof_net,         //bit 68
                             s_md_tx_eof_net,         //bit 67
                             s_md_tx_len_net[2:0],    //bit 66:64
                             s_md_tx_data_net[63:0]}; //bit 63:0

//net to net fifo
async_fifo #(
    .WIDTH        ( 64 + 3 + 1 + 1            )
    )
    u_net_fifo
    (
    .clk_write    ( i_clk_net                 ),
    .data_in      ( s_net_fifo_data_in[68:0]  ),
    .wren         ( s_md_tx_vld_net           ),
    .full         ( s_net_fifo_full           ),

    .clk_read     ( i_clk_net                 ),
    .data_out     ( s_net_fifo_data_out[68:0] ),
    .vld          ( s_net_fifo_valid          ),
    .rden         ( s_net_fifo_rden           ),
    .almost_empty ( s_net_fifo_almost_empty   )
    );

//md tx pkt counter from sof
always @ (posedge i_clk_net)
begin
    if(s_md_tx_vld_net == 1'b1 && s_md_tx_eof_net == 1'b1)
        s_md_tx_pkt_cnt <= 'd0;
    else if(s_md_tx_vld_net == 1'b1 && s_md_tx_sof_net == 1'b1)
        s_md_tx_pkt_cnt <= 'd1;
    else if(s_md_tx_sof_flag == 1'b1 && s_md_tx_vld_net == 1'b1 && s_md_tx_pkt_cnt != 'd255)
        s_md_tx_pkt_cnt <= s_md_tx_pkt_cnt + 'd1;
    else;
end

always @ (posedge i_clk_net)
begin
    s_md_tx_pkt_cnt_d1 <= s_md_tx_pkt_cnt;
end

//fifo read: buffer to avoid mac tx underflow
always @ (posedge i_clk_net)
begin
    if(o_tx_vld_net == 1'b1 && o_tx_eof_net == 1'b1)
        s_net_fifo_buf_rden <= 1'b0;
    else if(s_md_tx_vld_net == 1'b1 && s_md_tx_pkt_cnt == i_net_fifo_rd_thresh[7:0])
        s_net_fifo_buf_rden <= 1'b1;
    else;
end

//fifo rden
assign s_net_fifo_rden = i_tx_ack_net & s_net_fifo_buf_rden;

//net output
assign o_tx_data_net = s_net_fifo_data_out[63:0];
assign o_tx_len_net  = s_net_fifo_data_out[66:64];
assign o_tx_sof_net  = s_net_fifo_data_out[68] & s_net_fifo_valid;
assign o_tx_eof_net  = s_net_fifo_data_out[67];
assign o_tx_vld_net  = s_net_fifo_valid & s_net_fifo_rden;

//net tx sof flag
always @(posedge i_clk_net)
begin
    if(o_tx_vld_net == 1'b1 && o_tx_eof_net == 1'b1)
        s_net_tx_sof_flag <= 1'b0;
    else if(o_tx_vld_net == 1'b1 && o_tx_sof_net == 1'b1)
        s_net_tx_sof_flag <= 1'b1;
    else;
end

//net fifo full cnt
always @(posedge i_clk_net)
begin
    if(i_soft_reset == 1'b1)
        s_net_fifo_full_cnt <= 'd0;
    else if(s_md_tx_vld_net == 1'b1 && s_net_fifo_full == 1'b1)
        s_net_fifo_full_cnt <= s_net_fifo_full_cnt + 'd1;
    else;
end

//net tx cnt
always @(posedge i_clk_net)
begin
    if(i_soft_reset == 1'b1)
        s_net_tx_cnt <= 'd0;
    else if(s_net_tx_sof_flag == 1'b1 && o_tx_vld_net == 1'b1 && o_tx_eof_net == 1'b1)
        s_net_tx_cnt <= s_net_tx_cnt + 'd1;
    else;
end

//ack low stat
always @(posedge i_clk_net)
begin
    if(i_soft_reset == 1'b1)
        s_net_ack_low_cnt <= 'd0;
    else if(o_tx_vld_net == 1'b1 && i_tx_ack_net == 1'b0)
        s_net_ack_low_cnt <= s_net_ack_low_cnt + 'd1;
    else;
end


//-----------------------------------------------------------
// 3. output dma port
//-----------------------------------------------------------

//fifo data input
assign s_dma_fifo_data_in = {s_md_tx_sof_net,        //bit 70
                             s_md_tx_eof_net,        //bit 69
                             s_md_tx_err_net,        //bit 68
                             s_md_tx_len_net[2:0],   //bit 67:65
                             s_md_tx_data_net[63:0], //bit 64:1
                             s_md_tx_crc_fail_net};  //bit 0

//net to dma fifo
async_fifo #(
    .WIDTH        ( 64 + 3 + 1 + 1 + 1 + 1    )
    )
    u_dma_fifo
    (
    .clk_write    ( i_clk_net                 ),
    .data_in      ( s_dma_fifo_data_in[70:0]  ),
    .wren         ( s_md_tx_vld_net           ),
    .full         ( s_dma_fifo_full           ),

    .clk_read     ( i_clk_host                ),
    .data_out     ( s_dma_fifo_data_out[70:0] ),
    .vld          ( s_dma_fifo_valid          ),
    .rden         ( 1'b1                      ),
    .almost_empty ( s_dma_fifo_almost_empty   )
    );

//dma output
assign o_tx_data_host      = s_dma_fifo_data_out[64:1];
assign o_tx_len_host       = s_dma_fifo_data_out[67:65];
assign o_tx_vld_host       = s_dma_fifo_valid;
assign o_tx_sof_host       = s_dma_fifo_data_out[70] & s_dma_fifo_valid;
assign o_tx_eof_host       = s_dma_fifo_data_out[69];
assign o_tx_err_host       = s_dma_fifo_data_out[68];
assign o_tx_crc_fail_host  = s_dma_fifo_data_out[0];
assign o_tx_timestamp_host = s_md_tx_timestamp_net[31:0];
assign o_tx_match_host     = 8'b0;
assign o_tx_buffer_host    = 6'b0;

//dma tx sof flag
always @ (posedge i_clk_host)
begin
    if(o_tx_vld_host == 1'b1 && o_tx_eof_host == 1'b1)
        s_dma_tx_sof_flag <= 1'b0;
    else if(o_tx_vld_host == 1'b1 && o_tx_sof_host == 1'b1)
        s_dma_tx_sof_flag <= 1'b1;
    else;
end

//net to dma pkt cnt
always @ (posedge i_clk_host)
begin
    if(i_soft_reset == 1'b1)
        o_dma_tx_cnt <= 'd0;
    else if(s_dma_tx_sof_flag == 1'b1 && o_tx_vld_host == 1'b1 && o_tx_eof_host == 1'b1)
        o_dma_tx_cnt <= o_dma_tx_cnt + 'd1;
    else;
end


//-----------------------------------------------------------
// 4. stats cross to 250m
//-----------------------------------------------------------

always @ (posedge i_clk_host)
begin
    s_net_rx_cnt_d1     <= s_net_rx_cnt;
    o_net_rx_cnt        <= s_net_rx_cnt_d1;
    s_net_rx_err_cnt_d1 <= s_net_rx_err_cnt;
    o_net_rx_err_cnt    <= s_net_rx_err_cnt_d1;
    s_md_rx_cnt_d1      <= s_md_rx_cnt;
    o_md_rx_cnt         <= s_md_rx_cnt_d1;
    s_md_drop_cnt_d1    <= s_md_drop_cnt;
    o_md_drop_cnt       <= s_md_drop_cnt_d1;
    s_md_tx_cnt_d1      <= s_md_tx_cnt;
    o_md_tx_cnt         <= s_md_tx_cnt_d1;
    s_sn_reg_d1         <= s_sn_reg;
    o_sn_reg            <= s_sn_reg_d1;
    s_sn_discont_cnt_d1 <= s_sn_discont_cnt;
    o_sn_discont_cnt    <= s_sn_discont_cnt_d1;

    s_net_tx_cnt_d1        <= s_net_tx_cnt;
    o_net_tx_cnt           <= s_net_tx_cnt_d1;
    s_net_ack_low_cnt_d1   <= s_net_ack_low_cnt;
    o_net_ack_low_cnt      <= s_net_ack_low_cnt_d1;
    s_net_fifo_full_cnt_d1 <= s_net_fifo_full_cnt;
    o_net_fifo_full_cnt    <= s_net_fifo_full_cnt_d1;
end



endmodule
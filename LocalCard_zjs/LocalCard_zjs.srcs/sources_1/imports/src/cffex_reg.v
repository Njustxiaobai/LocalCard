// --------------------------------------------------------------------------------
// (c) Copyright 2017-2020 Meridian Technologies. All rights reserved.
//
// Tool Version: Vivado 2018.3
// Design      : cffex_reg.v
// Author      : liuchaofan
// Called by   : cffex_opt.v
// Description : filter to net output module
// Date        : 2020-07-22
// Verson      : 1.0
// --------------------------------------------------------------------------------
// Verson Description
// 1.00   2020-07-22       The initial verson
// --------------------------------------------------------------------------------
module cffex_reg #(
    parameter              VERSION_DATE         = 32'h0 ,
    parameter              VERSION_NUM          = 32'h0
    )
    (
    input  wire            i_clk_net                    ,
    input  wire            i_clk_host                   ,
    input  wire            i_rst_n                      ,
    //register interface
    input  wire            i_reg_w_en                   ,
    input  wire [10:0]     i_reg_w_addr                 ,
    input  wire [31:0]     i_reg_w_data                 ,
    input  wire [10:0]     i_reg_r_addr                 ,
    input  wire            i_reg_r_en                   ,
    output reg  [31:0]     o_reg_r_data                 ,
    output reg             o_reg_r_ack          = 1'b0  ,
    //reg
    output reg             o_soft_reset         = 1'b0  ,
    output reg  [7:0]      o_net_fifo_rd_thresh = 'd4   ,//网口发送FIFO读取缓存阈值
    input  wire [31:0]     i_net_rx_cnt                 ,//原始数据接收总包数
    input  wire [31:0]     i_net_rx_err_cnt             ,//原始数据接收错包数
    input  wire [31:0]     i_md_rx_cnt                  ,//组播行情接收总包数
    input  wire [31:0]     i_md_drop_cnt                ,//组播行情过滤丢弃总包数
    input  wire [31:0]     i_md_tx_cnt                  ,//组播行情过滤后总包数
    input  wire [31:0]     i_sn_reg                     ,//当前更新到的SN序号值
    input  wire [31:0]     i_sn_discont_cnt             ,//SN序号不连续计数
    input  wire [31:0]     i_net_fifo_full_cnt          ,//网口发送FIFO满统计
    input  wire [31:0]     i_net_tx_cnt                 ,//过滤行情网口转发总包数
    input  wire [31:0]     i_net_ack_low_cnt            ,//过滤行情发送网口反压统计
    input  wire [31:0]     i_dma_tx_cnt					 //过滤行情DMA口转发总包数
    );

//signal declare
reg         s_reg_r_en_1dly = 1'b0;
reg         s_reg_ack = 1'b0;
reg         s_reset_cmd = 1'b0;
reg         s_reset_cmd_d1 = 1'b0;
reg         s_reset_cmd_d2 = 1'b0;

//reg read ack
always @(posedge i_clk_host)
begin
    s_reg_r_en_1dly <= i_reg_r_en;
end

always @(posedge i_clk_host)
begin
    if ((i_reg_r_en == 1'b1) && (s_reg_r_en_1dly == 1'b0))
        o_reg_r_ack <= 1'b1;
    else
        o_reg_r_ack <= 1'b0;
end

//reg read
always @(posedge i_clk_host)
begin
    if (i_reg_r_en == 1'b1)
        case(i_reg_r_addr)
            //system
            11'h0  : o_reg_r_data <= VERSION_DATE;
            11'h4  : o_reg_r_data <= VERSION_NUM;
            11'h10 : o_reg_r_data <= {31'h0, s_reset_cmd};
            //md filter
            11'h100: o_reg_r_data <= i_net_rx_cnt[31:0];
            11'h104: o_reg_r_data <= i_net_rx_err_cnt[31:0];
            11'h120: o_reg_r_data <= i_md_rx_cnt[31:0];
            11'h124: o_reg_r_data <= i_md_drop_cnt[31:0];
            11'h128: o_reg_r_data <= i_md_tx_cnt[31:0];
            11'h130: o_reg_r_data <= i_sn_reg[31:0];
            11'h134: o_reg_r_data <= i_sn_discont_cnt[31:0];
            //net tx
            11'h200: o_reg_r_data <= i_net_tx_cnt[31:0];
            11'h204: o_reg_r_data <= i_net_ack_low_cnt[31:0];
            11'h210: o_reg_r_data <= {24'h0, o_net_fifo_rd_thresh[7:0]};
            11'h220: o_reg_r_data <= i_net_fifo_full_cnt[31:0];
            //dma tx
            11'h300: o_reg_r_data <= i_dma_tx_cnt[31:0];
            default: o_reg_r_data <= 32'h0;
        endcase
    else ;
end

//reg write
//reset reg
always @(posedge i_clk_host)
begin
    if((i_reg_w_en == 1'b1) && (i_reg_w_addr == 32'h10))
        s_reset_cmd <= i_reg_w_data[0];
    else
        s_reset_cmd <= 1'b0;
end

always @(posedge i_clk_host)
begin
    s_reset_cmd_d1 <= s_reset_cmd;
    s_reset_cmd_d2 <= s_reset_cmd_d1;
end

always @(posedge i_clk_host)
begin
    o_soft_reset <= s_reset_cmd | s_reset_cmd_d1 | s_reset_cmd_d2;
end

//net fifo read threshold
always @(posedge i_clk_host)
begin
    if((i_reg_w_en == 1'b1) && (i_reg_w_addr == 32'h210))
        o_net_fifo_rd_thresh <= i_reg_w_data[7:0];
    else;
end



endmodule
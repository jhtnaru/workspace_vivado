//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2024.2 (lin64) Build 5239630 Fri Nov 08 22:34:34 MST 2024
//Date        : Fri Sep 19 08:24:51 2025
//Host        : user16-B70TV-AN5TB8W running 64-bit Ubuntu 24.04.3 LTS
//Command     : generate_target soc_rtc_read_wrapper.bd
//Design      : soc_rtc_read_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module soc_rtc_read_wrapper
   (reset,
    rtc_clk_0,
    rtc_dat_0,
    rtc_rst_0,
    sys_clock,
    usb_uart_rxd,
    usb_uart_txd);
  input reset;
  output rtc_clk_0;
  inout rtc_dat_0;
  output rtc_rst_0;
  input sys_clock;
  input usb_uart_rxd;
  output usb_uart_txd;

  wire reset;
  wire rtc_clk_0;
  wire rtc_dat_0;
  wire rtc_rst_0;
  wire sys_clock;
  wire usb_uart_rxd;
  wire usb_uart_txd;

  soc_rtc_read soc_rtc_read_i
       (.reset(reset),
        .rtc_clk_0(rtc_clk_0),
        .rtc_dat_0(rtc_dat_0),
        .rtc_rst_0(rtc_rst_0),
        .sys_clock(sys_clock),
        .usb_uart_rxd(usb_uart_rxd),
        .usb_uart_txd(usb_uart_txd));
endmodule

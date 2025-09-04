//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2024.2 (lin64) Build 5239630 Fri Nov 08 22:34:34 MST 2024
//Date        : Wed Sep  3 16:33:51 2025
//Host        : user16-B70TV-AN5TB8W running 64-bit Ubuntu 24.04.3 LTS
//Command     : generate_target soc_btn_fnd_wrapper.bd
//Design      : soc_btn_fnd_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module soc_btn_fnd_wrapper
   (com_0,
    dp_0,
    push_buttons_4bits_tri_i,
    reset,
    seg_7_0,
    sys_clock,
    usb_uart_rxd,
    usb_uart_txd);
  output [3:0]com_0;
  output dp_0;
  input [3:0]push_buttons_4bits_tri_i;
  input reset;
  output [6:0]seg_7_0;
  input sys_clock;
  input usb_uart_rxd;
  output usb_uart_txd;

  wire [3:0]com_0;
  wire dp_0;
  wire [3:0]push_buttons_4bits_tri_i;
  wire reset;
  wire [6:0]seg_7_0;
  wire sys_clock;
  wire usb_uart_rxd;
  wire usb_uart_txd;

  soc_btn_fnd soc_btn_fnd_i
       (.com_0(com_0),
        .dp_0(dp_0),
        .push_buttons_4bits_tri_i(push_buttons_4bits_tri_i),
        .reset(reset),
        .seg_7_0(seg_7_0),
        .sys_clock(sys_clock),
        .usb_uart_rxd(usb_uart_rxd),
        .usb_uart_txd(usb_uart_txd));
endmodule

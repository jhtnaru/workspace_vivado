//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2024.2 (lin64) Build 5239630 Fri Nov 08 22:34:34 MST 2024
//Date        : Wed Sep 17 14:17:59 2025
//Host        : user16-B70TV-AN5TB8W running 64-bit Ubuntu 24.04.3 LTS
//Command     : generate_target soc_servo180_wrapper.bd
//Design      : soc_servo180_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module soc_servo180_wrapper
   (push_buttons_4bits_tri_i,
    reset,
    servo_0,
    sys_clock,
    usb_uart_rxd,
    usb_uart_txd);
  input [3:0]push_buttons_4bits_tri_i;
  input reset;
  output servo_0;
  input sys_clock;
  input usb_uart_rxd;
  output usb_uart_txd;

  wire [3:0]push_buttons_4bits_tri_i;
  wire reset;
  wire servo_0;
  wire sys_clock;
  wire usb_uart_rxd;
  wire usb_uart_txd;

  soc_servo180 soc_servo180_i
       (.push_buttons_4bits_tri_i(push_buttons_4bits_tri_i),
        .reset(reset),
        .servo_0(servo_0),
        .sys_clock(sys_clock),
        .usb_uart_rxd(usb_uart_rxd),
        .usb_uart_txd(usb_uart_txd));
endmodule

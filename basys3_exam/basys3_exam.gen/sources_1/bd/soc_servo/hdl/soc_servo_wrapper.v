//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2024.2 (lin64) Build 5239630 Fri Nov 08 22:34:34 MST 2024
//Date        : Tue Sep 23 12:28:23 2025
//Host        : user16-B70TV-AN5TB8W running 64-bit Ubuntu 24.04.3 LTS
//Command     : generate_target soc_servo_wrapper.bd
//Design      : soc_servo_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module soc_servo_wrapper
   (push_buttons_4bits_tri_i,
    reset,
    servo_0,
    servo_1,
    servo_2,
    servo_3,
    servo_4,
    servo_5,
    servo_6,
    sys_clock,
    usb_uart_rxd,
    usb_uart_txd);
  input [3:0]push_buttons_4bits_tri_i;
  input reset;
  output servo_0;
  output servo_1;
  output servo_2;
  output servo_3;
  output servo_4;
  output servo_5;
  output servo_6;
  input sys_clock;
  input usb_uart_rxd;
  output usb_uart_txd;

  wire [3:0]push_buttons_4bits_tri_i;
  wire reset;
  wire servo_0;
  wire servo_1;
  wire servo_2;
  wire servo_3;
  wire servo_4;
  wire servo_5;
  wire servo_6;
  wire sys_clock;
  wire usb_uart_rxd;
  wire usb_uart_txd;

  soc_servo soc_servo_i
       (.push_buttons_4bits_tri_i(push_buttons_4bits_tri_i),
        .reset(reset),
        .servo_0(servo_0),
        .servo_1(servo_1),
        .servo_2(servo_2),
        .servo_3(servo_3),
        .servo_4(servo_4),
        .servo_5(servo_5),
        .servo_6(servo_6),
        .sys_clock(sys_clock),
        .usb_uart_rxd(usb_uart_rxd),
        .usb_uart_txd(usb_uart_txd));
endmodule

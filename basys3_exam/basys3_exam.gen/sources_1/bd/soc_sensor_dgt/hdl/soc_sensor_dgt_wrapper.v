//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2024.2 (lin64) Build 5239630 Fri Nov 08 22:34:34 MST 2024
//Date        : Sun Sep 21 11:08:25 2025
//Host        : user16-B70TV-AN5TB8W running 64-bit Ubuntu 24.04.3 LTS
//Command     : generate_target soc_sensor_dgt_wrapper.bd
//Design      : soc_sensor_dgt_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module soc_sensor_dgt_wrapper
   (reset,
    sensor_0,
    sys_clock,
    usb_uart_rxd,
    usb_uart_txd);
  input reset;
  input sensor_0;
  input sys_clock;
  input usb_uart_rxd;
  output usb_uart_txd;

  wire reset;
  wire sensor_0;
  wire sys_clock;
  wire usb_uart_rxd;
  wire usb_uart_txd;

  soc_sensor_dgt soc_sensor_dgt_i
       (.reset(reset),
        .sensor_0(sensor_0),
        .sys_clock(sys_clock),
        .usb_uart_rxd(usb_uart_rxd),
        .usb_uart_txd(usb_uart_txd));
endmodule

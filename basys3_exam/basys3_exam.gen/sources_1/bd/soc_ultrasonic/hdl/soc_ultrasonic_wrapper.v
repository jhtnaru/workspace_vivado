//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2024.2 (lin64) Build 5239630 Fri Nov 08 22:34:34 MST 2024
//Date        : Fri Sep  5 14:45:37 2025
//Host        : user16-B70TV-AN5TB8W running 64-bit Ubuntu 24.04.3 LTS
//Command     : generate_target soc_ultrasonic_wrapper.bd
//Design      : soc_ultrasonic_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module soc_ultrasonic_wrapper
   (led_0,
    reset,
    sys_clock,
    ultra_echo_0,
    ultra_trig_0,
    usb_uart_rxd,
    usb_uart_txd);
  output [15:0]led_0;
  input reset;
  input sys_clock;
  input ultra_echo_0;
  output ultra_trig_0;
  input usb_uart_rxd;
  output usb_uart_txd;

  wire [15:0]led_0;
  wire reset;
  wire sys_clock;
  wire ultra_echo_0;
  wire ultra_trig_0;
  wire usb_uart_rxd;
  wire usb_uart_txd;

  soc_ultrasonic soc_ultrasonic_i
       (.led_0(led_0),
        .reset(reset),
        .sys_clock(sys_clock),
        .ultra_echo_0(ultra_echo_0),
        .ultra_trig_0(ultra_trig_0),
        .usb_uart_rxd(usb_uart_rxd),
        .usb_uart_txd(usb_uart_txd));
endmodule

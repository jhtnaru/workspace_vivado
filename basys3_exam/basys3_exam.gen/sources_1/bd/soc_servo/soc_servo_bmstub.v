// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
// -------------------------------------------------------------------------------

`timescale 1 ps / 1 ps

(* BLOCK_STUB = "true" *)
module soc_servo (
  reset,
  sys_clock,
  usb_uart_rxd,
  usb_uart_txd,
  push_buttons_4bits_tri_i,
  servo_0,
  servo_1,
  servo_2,
  servo_3,
  servo_4,
  servo_5,
  servo_6
);

  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 RST.RESET RST" *)
  (* X_INTERFACE_MODE = "slave RST.RESET" *)
  (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME RST.RESET, POLARITY ACTIVE_HIGH, INSERT_VIP 0" *)
  input reset;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK.SYS_CLOCK CLK" *)
  (* X_INTERFACE_MODE = "slave CLK.SYS_CLOCK" *)
  (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME CLK.SYS_CLOCK, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN soc_servo_sys_clock, INSERT_VIP 0" *)
  input sys_clock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:uart:1.0 usb_uart RxD" *)
  (* X_INTERFACE_MODE = "master usb_uart" *)
  input usb_uart_rxd;
  (* X_INTERFACE_INFO = "xilinx.com:interface:uart:1.0 usb_uart TxD" *)
  output usb_uart_txd;
  (* X_INTERFACE_INFO = "xilinx.com:interface:gpio:1.0 push_buttons_4bits TRI_I" *)
  (* X_INTERFACE_MODE = "master push_buttons_4bits" *)
  input [3:0]push_buttons_4bits_tri_i;
  (* X_INTERFACE_IGNORE = "true" *)
  output servo_0;
  (* X_INTERFACE_IGNORE = "true" *)
  output servo_1;
  (* X_INTERFACE_IGNORE = "true" *)
  output servo_2;
  (* X_INTERFACE_IGNORE = "true" *)
  output servo_3;
  (* X_INTERFACE_IGNORE = "true" *)
  output servo_4;
  (* X_INTERFACE_IGNORE = "true" *)
  output servo_5;
  (* X_INTERFACE_IGNORE = "true" *)
  output servo_6;

  // stub module has no contents

endmodule

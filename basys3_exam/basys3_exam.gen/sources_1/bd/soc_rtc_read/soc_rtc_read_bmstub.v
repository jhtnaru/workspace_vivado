// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
// -------------------------------------------------------------------------------

`timescale 1 ps / 1 ps

(* BLOCK_STUB = "true" *)
module soc_rtc_read (
  reset,
  sys_clock,
  usb_uart_rxd,
  usb_uart_txd,
  rtc_clk_0,
  rtc_dat_0,
  rtc_rst_0
);

  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 RST.RESET RST" *)
  (* X_INTERFACE_MODE = "slave RST.RESET" *)
  (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME RST.RESET, POLARITY ACTIVE_HIGH, INSERT_VIP 0" *)
  input reset;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK.SYS_CLOCK CLK" *)
  (* X_INTERFACE_MODE = "slave CLK.SYS_CLOCK" *)
  (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME CLK.SYS_CLOCK, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN soc_rtc_read_sys_clock, INSERT_VIP 0" *)
  input sys_clock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:uart:1.0 usb_uart RxD" *)
  (* X_INTERFACE_MODE = "master usb_uart" *)
  input usb_uart_rxd;
  (* X_INTERFACE_INFO = "xilinx.com:interface:uart:1.0 usb_uart TxD" *)
  output usb_uart_txd;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK.RTC_CLK_0 CLK" *)
  (* X_INTERFACE_MODE = "master CLK.RTC_CLK_0" *)
  (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME CLK.RTC_CLK_0, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN soc_rtc_read_myip_rtc_read_0_0_rtc_clk, INSERT_VIP 0" *)
  output rtc_clk_0;
  (* X_INTERFACE_IGNORE = "true" *)
  inout rtc_dat_0;
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 RST.RTC_RST_0 RST" *)
  (* X_INTERFACE_MODE = "master RST.RTC_RST_0" *)
  (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME RST.RTC_RST_0, POLARITY ACTIVE_LOW, INSERT_VIP 0" *)
  output rtc_rst_0;

  // stub module has no contents

endmodule

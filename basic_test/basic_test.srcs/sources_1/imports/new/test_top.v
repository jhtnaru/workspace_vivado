`timescale 1ns / 1ps

// GY-65 센서 값 읽기 전용 Top Module
module gy65_top_system (
    input clk, reset_p,
    input [3:0] btn,
    inout sda,           // I2C 데이터 라인
    output scl,          // I2C 클럭 라인
    output [6:0] seg_7,
    output dp,
    output [3:0] com,
    output [15:0] led
    );

    wire start_pulse = btn_pedge[0];
    wire [3:0] btn_pedge;
    btn_cntr btn0 (clk, reset_p, btn[0], btn_pedge[0]);
    btn_cntr btn1 (clk, reset_p, btn[1], btn_pedge[1]);
    btn_cntr btn2 (clk, reset_p, btn[2], btn_pedge[2]);
    btn_cntr btn3 (clk, reset_p, btn[3], btn_pedge[3]);

    wire [31:0] pressure_pa;     // 계산된 압력 (Pa)
    wire [15:0] temperature_c;   // 계산된 온도 (0.1도 단위)
    wire [31:0] altitude_cm;     // 계산된 고도 (cm)
    wire data_ready;   // 데이터 준비 완료
    wire busy;         // 측정 중
    wire error;        // 에러 발생
    gy65_bmp180_cntr sensor_inst (.clk(clk), .reset_p(reset_p),
        .start(start_pulse), .sda(sda), .scl(scl),
        .pressure_pa(pressure_pa), .temperature_c(temperature_c), .altitude_cm(altitude_cm),
        .data_ready(data_ready), .busy(busy), .error(error));

    assign led = pressure_pa[15:0];

    // FND 4-Digit Output
    fnd_cntr fnd (.clk(clk), .reset_p(reset_p),
        .fnd_value(temperature_c), .hex_bcd(0), .seg_7(seg_7), .dp(dp), .com(com));
endmodule
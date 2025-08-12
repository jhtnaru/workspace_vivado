`timescale 1ns / 1ps

// Clock Divide Asynchronous LED Ring Counter
module ring_counter_led_top (
    input clk, reset_p,
    output reg [15:0] led
    );

    reg [20:0] clk_div;

    // 서로 다른 Clock 사용하기 때문에 비동기
    always @(posedge clk) begin
        clk_div = clk_div + 1;
    end

    wire clk_div_18;
    edge_detector_pos clk_div_edge (.clk(clk), .reset_p(reset_p),
                                    .cp(clk_div[18]), .p_edge(clk_div_18));

    // clk_div[0] → clk 2주기 = clk_div 1주기, 다른 자리로 갈수록 2 분주
    // clk_div[16] 정도면 모두 동시에 켜있는것처럼 보임
    // always @(posedge clk_div[16] or posedge reset_p) begin
    
    // 동기식으로 변경, clk, reset_p만 사용
    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            led = 16'b0000_0000_0000_0001;
        end
        else if (clk_div_18) begin
            led = {led[14:0], led[15]};
        end
    end
endmodule

// Minute, Second Clock
module watch_top (
    input clk, reset_p,     // System Clock, Reset Button
    input [2:0] btn,
    output [6:0] seg_7,     // FND 7-Segment Output
    output dp,              // FND DP Output
    output [3:0] com,       // FND Select
    output [15:0] led
    );

    // Button Input Debounce + Prevent Duplicate Processing
    wire btn_mode, inc_sec, inc_min;
    btn_cntr mode_btn (.clk(clk), .reset_p(reset_p), .btn(btn[0]), .btn_pedge(btn_mode));
    btn_cntr inc_sec_btn (.clk(clk), .reset_p(reset_p), .btn(btn[1]), .btn_pedge(inc_sec));
    btn_cntr inc_min_btn (.clk(clk), .reset_p(reset_p), .btn(btn[2]), .btn_pedge(inc_min));

    reg set_watch;
    assign led[0] = set_watch;

    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin                          // Mode Reset
            set_watch = 0;
        end
        else if (btn_mode) begin
            set_watch = ~set_watch;                 // Mode Toggle
        end
    end

    reg [26:0] cnt_sysclk;                          // Clock Division
    reg [11:0] sec, min;                            // bcd_to_dec Input Format 12-bit
    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin                          // Time Reset
            cnt_sysclk = 1;
            sec = 0;
            min = 0;
        end
        else begin
            if (set_watch) begin
                if (inc_sec) begin
                    if (sec >= 59) begin
                        sec = 0;
                    end
                    else begin
                        sec = sec + 1;
                    end
                end
                if (inc_min) begin
                    if (min >= 59) begin
                        min = 0;
                    end
                    else begin
                        min = min + 1;
                    end
                end
            end
            else begin
                if (cnt_sysclk >= 27'd100_000_000) begin    // 10ns x 100,000,000 = 1s
                    cnt_sysclk = 1;
                    if (sec >= 59) begin                    // 0 ~ 59 Second Count
                        sec = 0;
                        if (min >= 59) begin                // 0 ~ 59 Minute Count
                            min = 0;
                        end
                        else begin
                            min = min + 1;
                        end
                    end
                    else begin
                        sec = sec + 1;
                    end
                end
                cnt_sysclk = cnt_sysclk + 1;                // Count for Clock Division
            end
        end
    end

    // BCD Format Conversion
    wire [15:0] sec_bcd, min_bcd;
    bin_to_dec bcd_sec (.bin(sec), .bcd(sec_bcd));
    bin_to_dec bcd_min (.bin(min), .bcd(min_bcd));

    // FND 4-Digit Output
    fnd_cntr fnd (.clk(clk), .reset_p(reset_p),
                .fnd_value({min_bcd[7:0], sec_bcd[7:0]}), .hex_bcd(1),
                .seg_7(seg_7), .dp(dp), .com(com));
endmodule

// Down Count Timer
module cook_timer (
    input clk, reset_p,
    input [3:0] btn,                                // Button Input
    output [6:0] seg_7,                             // 7-Segment Output
    output dp,                                      // Dot Point Output
    output [3:0] com,                               // FND Digit Select
    output reg alarm,                               // Alarm Output
    output [15:0] led                               // For Debugging
    );

    reg start_set;                                  // State & Mode, Start ↔ Stop & Set
    reg [26:0] cnt_sysclk;                          // Clock Division Count
    reg [11:0] sec, min;                            // Time, bcd_to_dec Input Format 12-bit
    reg [7:0] set_sec, set_min;                     // Previous Time
    reg set_flag;                                   // Alarm Off Flag
    wire btn_mode, inc_sec, inc_min, alarm_off;     // Adjusted Button Input 
    wire [15:0] sec_bcd, min_bcd;

    // Button Input Debounce + Prevent Duplicate Processing
    btn_cntr mode_btn (
        .clk(clk), .reset_p(reset_p), .btn(btn[0]), .btn_pedge(btn_mode));
    btn_cntr inc_sec_btn (
        .clk(clk), .reset_p(reset_p), .btn(btn[1]), .btn_pedge(inc_sec));
    btn_cntr inc_min_btn (
        .clk(clk), .reset_p(reset_p), .btn(btn[2]), .btn_pedge(inc_min));
    btn_cntr alarm_off_btn (
        .clk(clk), .reset_p(reset_p), .btn(btn[3]), .btn_pedge(alarm_off));

    assign led[0] = start_set;                      // State Output
    assign led[15] = alarm;
    always @(posedge clk, posedge reset_p) begin
        // State Reset
        if (reset_p) begin
            start_set = 0;                          // State Stop, Set Mode
            alarm = 0;                              // Alarm Off
            set_flag = 0;
        end
        // Mode Button Input & State Stop
        else if (btn_mode && start_set == 0 && alarm == 0) begin
            // Start Only when Seconds and Minutes not 0
            if (sec != 0 || min != 0) begin
                start_set = 1;                      // Mode Start
                set_sec = sec;                      // Save Previous Seconds
                set_min = min;                      // Save Previous Minutes
            end
        end
        // Mode Button Input & State Start
        else if (btn_mode && start_set && alarm == 0) begin
            start_set = 0;                          // Mode Stop
        end
        // Alarm when 0 Minutes, 0 Seconds Pass
        else if (start_set && min == 0 && sec == 0) begin
            start_set = 0;                          // Mode Start → Stop
            alarm = 1;                              // Alarm On
        end
        // Button Input → Alarm Off
        else if (alarm && (alarm_off || inc_sec || inc_min || btn_mode)) begin
            alarm = 0;                              // Alarm Off
            set_flag = 1;                           // Alarm Flag On
        end
        // Alarm Flag On & Seconds and Minutes not 0
        else if (set_flag && (sec != 0 || min != 0)) begin
            set_flag = 0;                           // Alarm Flag Clear
        end
    end

    always @(posedge clk, posedge reset_p) begin
        // Time Reset
        if (reset_p) begin
            cnt_sysclk = 1;                         // Clock Division Count Reset
            sec = 0;                                // Second Reset
            min = 0;                                // Minute Reset
        end
        else begin
            // State Start
            if (start_set) begin
                // Clock Divide, 10ns x 100,000,000 = 1 Second
                if (cnt_sysclk >= 100_000_000) begin
                    cnt_sysclk = 1;                 // Clock Division Count Reset
                    // 0 Seconds Pass
                    if (sec == 0) begin
                        // Minutes not 0
                        if (min) begin
                            sec = 59;               // 0 ~ 59 Second Count
                            min = min - 1;          // Minute Down Count
                        end
                    end
                    else begin
                        sec = sec - 1;              // Second Down Count
                    end
                end
                else begin
                    cnt_sysclk = cnt_sysclk + 1;    // Count for Clock Division
                end
            end
            // State Stop, Set Mode
            else begin
                // 
                if (inc_sec && alarm == 0) begin
                    if(sec >= 59) begin             // 0 ~ 59 Second Set
                        sec = 0;
                    end
                    else begin
                        sec = sec + 1;              // Second Increase
                    end
                end
                if (inc_min && alarm == 0) begin
                    if (min >= 59) begin            // 0 ~ 59 Minute Set
                        min = 0;
                    end
                    else begin
                        min = min + 1;              // Minute Increase
                    end
                end
                // Alarm Flag On
                if (set_flag) begin
                    sec = set_sec;                  // Previous Second Set
                    min = set_min;                  // Previous Minute Set
                end
            end
        end
    end

    // BCD Format Conversion
    bin_to_dec bcd_sec (.bin(sec), .bcd(sec_bcd));
    bin_to_dec bcd_min (.bin(min), .bcd(min_bcd));

    // FND 4-Digit Output
    fnd_cntr fnd (.clk(clk), .reset_p(reset_p),
                .fnd_value({min_bcd[7:0], sec_bcd[7:0]}), .hex_bcd(1),
                .seg_7(seg_7), .dp(dp), .com(com));
endmodule
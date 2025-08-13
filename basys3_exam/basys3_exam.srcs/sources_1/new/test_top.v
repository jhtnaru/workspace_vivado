`timescale 1ns / 1ps

// Clock Divide Asynchronous LED Ring Counter
module ring_counter_led_top (
    input clk, reset_p,
    output reg [15:0] led
    );

    reg [20:0] clk_div;

    // Asynchronous when Using Different Clock
    // Synchronous when Using Same Clock
    always @(posedge clk) begin
        clk_div = clk_div + 1;
    end

    // 524_288ns Edge Detect
    wire clk_div_18;
    edge_detector_pos clk_div_edge (.clk(clk), .reset_p(reset_p),
                                    .cp(clk_div[18]), .p_edge(clk_div_18));

    // clk 2 Cycle = clk_div 1 Cycle
    // clk_div[16] Looks like Both On at Same Time
   
    // Change to Synchronous, Only clk, reset_p Using
    // always @(posedge clk_div[16] or posedge reset_p) begin
    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            led = 16'b0000_0000_0000_0001;      // Base LSB 0, Remaining Bit 0
        end
        else if (clk_div_18) begin              // Reaching Detected Edge
            // MSB → LSB & Bit Left Shift
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
            if (set_watch) begin                    // Stop & Set Mode
                if (inc_sec) begin
                    if (sec >= 59) begin            // 0 ~ 59 Second Count
                        sec = 0;
                    end
                    else begin
                        sec = sec + 1;              // Second Increase
                    end
                end
                if (inc_min) begin
                    if (min >= 59) begin            // 0 ~ 59 Minute Count
                        min = 0;
                    end
                    else begin
                        min = min + 1;              // Minute Increase
                    end
                end
            end
            else begin                              // Start Mode
                if (cnt_sysclk >= 27'd100_000_000) begin    // 10ns x 100,000,000 = 1s
                    cnt_sysclk = 1;
                    if (sec >= 59) begin            // 0 ~ 59 Second Count
                        sec = 0;
                        if (min >= 59) begin        // 0 ~ 59 Minute Count
                            min = 0;
                        end
                        else begin
                            min = min + 1;          // Secound Count
                        end
                    end
                    else begin
                        sec = sec + 1;              // Minute Count
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
    wire [15:0] sec_bcd, min_bcd;                   // BCD Conversion Format Time

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
    assign led[1] = alarm;
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


module stop_watch (
    input clk, reset_p,
    input [2:0] btn,                                // Button Input
    output [6:0] seg_7,                             // 7-Segment Output
    output dp,                                      // Dot Point Output
    output [3:0] com,                               // FND Digit Select
    output [15:0] led                               // For Debugging
    );

    wire btn_start, btn_lap, btn_clear;             // Adjusted Button Input
    reg start_stop;                                 // State & Mode, Start ↔ Stop
    reg lap;                                        // Middle Record Mode
    reg [26:0] cnt_sysclk;                          // Clock Division Count
    reg [7:0] sec, csec;                            // HEX Format Time, Second, Subsecond
    reg [7:0] lap_sec, lap_csec;                    // Middle Record Time
    wire [7:0] fnd_sec, fnd_csec;
    wire [7:0] sec_bcd, csec_bcd;                   // Conversion BCD Format Time

    assign led[0] = start_stop;                     // Start & Stop State Output
    assign led[1] = lap;                            // Middle Record State Output

    // Button Input Debounce + Prevent Duplicate Processing
    btn_cntr start_btn (
        .clk(clk), .reset_p(reset_p), .btn(btn[0]), .btn_pedge(btn_start));
    btn_cntr lap_btn (
        .clk(clk), .reset_p(reset_p), .btn(btn[1]), .btn_pedge(btn_lap));
    btn_cntr clear_btn (
        .clk(clk), .reset_p(reset_p), .btn(btn[2]), .btn_pedge(btn_clear));

    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin
            start_stop = 0;                         // Reset, Stop Mode
        end
        else if (btn_start) begin
            start_stop = ~start_stop;               // Mode Toggle, Start ↔ Stop
        end
    end

    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin
            lap = 0;                                // Lap Clear
            lap_sec = 0;                            // Middle Record Reset
            lap_csec = 0;
        end
        else if (btn_lap) begin                     // Input Lap Button
            lap = ~lap;                             // Mode Toggle, Middle Record Show ↔ Not Show
            lap_sec = sec;                          // Time Middle Record
            lap_csec = csec;
        end
        else if (btn_clear) begin                   // Input Clear Button
            lap = 0;                                // Lap Clear
            lap_sec = 0;                            // Middle Record Reset
            lap_csec = 0;
        end
    end

    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin
            cnt_sysclk = 1;                         // Clock Division Count Reset
            sec = 0;                                // Time Reset
            csec = 0;
        end
        else begin
            if (start_stop) begin
                if (cnt_sysclk >= 1_000_000) begin  // 1ns * 1,000,000 = 0.01s
                    cnt_sysclk = 1;                 // Clock Division Count Reset
                    if (csec >= 99) begin           // 0 ~ 99 Sub Second Count
                        csec = 0;
                        if (sec >= 99) begin        // 0 ~ 99 Second Count
                            sec = 0;
                        end
                        else begin
                            sec = sec + 1;          // Second Up Count
                        end
                    end
                    else begin
                        csec = csec + 1;            // Sub Second Up Count
                    end
                end
                else begin
                    cnt_sysclk = cnt_sysclk + 1;    // Count for Clock Division
                end
            end
            if (btn_clear) begin                    // Input Clear Button, Maintain Start State
                cnt_sysclk = 1;                     // Clock Division Count Reset
                sec = 0;                            // Time Reset
                csec = 0;
            end
        end
    end

    // Determine FND Output by Middle Recode Mode
    assign fnd_sec = lap ? lap_sec : sec;
    assign fnd_csec = lap ? lap_csec : csec;

    // BCD Format Conversion
    bin_to_dec bcd_sec (.bin(fnd_sec), .bcd(sec_bcd));
    bin_to_dec bcd_min (.bin(fnd_csec), .bcd(csec_bcd));

    // FND 4-Digit Output
    fnd_cntr fnd (.clk(clk), .reset_p(reset_p),
                .fnd_value({sec_bcd, csec_bcd}), .hex_bcd(1),
                .seg_7(seg_7), .dp(dp), .com(com));
endmodule

// Watch + Cook Timer + Stop Watch
module watch_collection (
    input clk, reset_p,
    input [3:0] btn,                                // Button Input
    input [1:0] sw,                                 // Switch Input, Select Mode
    output reg [6:0] seg_7,                         // 7-Segment Output
    output reg dp,                                  // Dot Point Output
    output reg [3:0] com,                           // FND Digit Select
    output [15:0] led,                              // For Debugging
    output alarm                                    // Alarm Output
    );

    reg [3:0] mode;                                 // Mode Output, [0] Base, [1] Watch, [2] Cook Timer, [3] Stop Watch
    reg led_0, led_1;                               // For State Output
    reg [15:0] base_time;                           // For Mode Base FND Output

    // Input Connection Variables
    reg [2:0] btn_w, btn_sw;                        // Watch, Stop Watch Use Buttons 0 to 2
    reg [3:0] btn_t;                                // Timer Use Buttons 0 to 3

    // Output Connection Variables
    wire [6:0] seg_b, seg_w, seg_t, seg_sw;         // 7-Segment Values by Mode
    wire dp_b, dp_w, dp_t, dp_sw;                   // DP Values by Mode
    wire [3:0] com_b, com_w, com_t, com_sw;         // FND Digit Values by Mode
    wire [15:0] led_b, led_w, led_t, led_sw;        // LED Values by Mode
    wire alarm_t;                                   // Alarm Values by Timer Mode

    assign led[0] = led_0;                          // State Output 1, Varies by Mode
    assign led[1] = led_1;                          // State Output 2, Varies by Mode
    assign led[15:12] = mode;                       // Mode LED Output
    assign alarm = alarm_t;                         // Alarm Output


    // Input & Output Connections for Each Clock
    // Base FND Output 0000
    fnd_cntr base (.clk(clk), .reset_p(reset_p),
                .fnd_value(base_time), .hex_bcd(1),
                .seg_7(seg_b), .dp(dp_b), .com(com_b));

    // Watch Connect using _w
    watch_top watch (.clk(clk), .reset_p(reset_p), .btn(btn_w),
                    .seg_7(seg_w), .dp(dp_w), .com(com_w), .led(led_w));

    // Cook Timer Connect using _t
    cook_timer timer (.clk(clk), .reset_p(reset_p), .btn(btn_t),
                    .seg_7(seg_t), .dp(dp_t), .com(com_t), .alarm(alarm_t), .led(led_t));

    // Stop Watch Connect using _sw
    stop_watch swatch (.clk(clk), .reset_p(reset_p), .btn(btn_sw),
                    .seg_7(seg_sw), .dp(dp_sw), .com(com_sw), .led(led_sw));

    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin                          // Reset = Base Mode
            mode = 4'b0001;                         // LED Output LD12
            seg_7 = seg_b;                          // Base FND Output 0000
            dp = dp_b;
            com = com_b;
        end
        else begin
            case (sw)
                2'd1 : begin                        // Select Watch Mode
                    mode = 4'b0010;                 // LED Output LD13
                    btn_w = btn[2:0];               // Button Input → Watch Button Input
                    seg_7 = seg_w;                  // Watch Output → FND Output
                    dp = dp_w;
                    com = com_w;
                    led_0 = led_w[0];               // Watch Start & Set State Output
                    led_1 = led_w[1];
                end
                2'd2 : begin                        // Select Cook Timer Mode
                    mode = 4'b0100;                 // LED Output LD14
                    btn_t = btn;                    // Button Input → Timer Button Input
                    seg_7 = seg_t;                  // Timer Output → FND Output
                    dp = dp_t;
                    com = com_t;
                    led_0 = led_t[0];               // Timer Start & Stop State Output
                    led_1 = led_t[1];               // Timer Alarm On ↔ Off Output
                end
                2'd3 : begin                        // Select Stop Watch Mode
                    mode = 4'b1000;                 // LED Output LD15
                    btn_sw = btn[2:0];              // Button Input → Stop Watch Button Input
                    seg_7 = seg_sw;                 // Stop Watch Output → FND Output
                    dp = dp_sw;
                    com = com_sw;
                    led_0 = led_sw[0];              // Stop Watch Start & Stop State Output
                    led_1 = led_sw[1];              // Stop Watch Lap State Output
                end
                default: begin                      // Default = Base Mode
                    mode = 4'b0001;                 // LED Output LD12
                    seg_7 = seg_b;                  // Base FND Output 0000
                    dp = dp_b;
                    com = com_b;
                end
            endcase
        end
    end
endmodule
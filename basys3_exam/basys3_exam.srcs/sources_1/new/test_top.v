`timescale 1ns / 1ps

// Clock Divide Asynchronous LED Ring Counter
module ring_counter_led_top (
    input clk, reset_p,
    output reg [15:0] led
    );

    reg [20:0] clk_div;                             // Clock Division
    wire clk_div_18;                                // Clock Division 2^19

    // Asynchronous when Using Different Clock, Synchronous when Using Same Clock
    always @(posedge clk) begin
        clk_div = clk_div + 1;
    end

    // 2^19ns = 524_288ns Edge Detect
    edge_detector_pos clk_div_edge (.clk(clk), .reset_p(reset_p),
                                    .cp(clk_div[18]), .p_edge(clk_div_18));

    // clk 2 Cycle = clk_div 1 Cycle
    // clk_div[16] Looks like Both On at Same Time
   
    // always @(posedge clk_div[16] or posedge reset_p) begin
    // Change to Synchronous, Only clk, reset_p Using
    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            led = 16'b0000_0000_0000_0001;          // Base LSB 0, Remaining Bit 0
        end
        else if (clk_div_18) begin                  // Reaching Detected Edge
            led = {led[14:0], led[15]};             // MSB → LSB & Bit Left Shift
        end
    end
endmodule

// Minute, Second Clock
module watch_top (
    input clk, reset_p,
    input [3:0] btn,                                // Input Button
    output [6:0] seg_7,                             // Output FND 7-Segment
    output dp,                                      // Output FND Dot Ppint
    output [3:0] com,                               // Output FND Digit Select
    output [15:0] led                               // Output LED for Debugging
    );

    wire btn_mode, inc_sec, inc_min, btn_clear;     // Button Input Values to Send
    wire [7:0] sec, min;                            // Received Time Value
    wire set_watch;                                 // Received Mode State
    wire [15:0] sec_bcd, min_bcd;                   // Convert Time Values to BCD Format

    assign led[0] = set_watch;                      // Mode State LED Output

    // Button Input Debounce + Prevent Duplicate Processing
    btn_cntr mode_btn (.clk(clk), .reset_p(reset_p), .btn(btn[0]), .btn_pedge(btn_mode));
    btn_cntr inc_sec_btn (.clk(clk), .reset_p(reset_p), .btn(btn[1]), .btn_pedge(inc_sec));
    btn_cntr inc_min_btn (.clk(clk), .reset_p(reset_p), .btn(btn[2]), .btn_pedge(inc_min));
    btn_cntr clear_btn (.clk(clk), .reset_p(reset_p), .btn(btn[3]), .btn_pedge(btn_clear));

    // Using Watch Module, Input Button, Output Time & Mode State
    watch watch_instance (.clk(clk), .reset_p(reset_p),
        .btn_mode(btn_mode), .inc_sec(inc_sec), .inc_min(inc_min), .btn_clear(btn_clear),
        .sec(sec), .min(min), .set_watch(set_watch));

    // BCD Format Conversion
    bin_to_dec bcd_sec (.bin(sec), .bcd(sec_bcd));
    bin_to_dec bcd_min (.bin(min), .bcd(min_bcd));

    // FND 4-Digit Output
    fnd_cntr fnd (.clk(clk), .reset_p(reset_p),
        .fnd_value({min_bcd[7:0], sec_bcd[7:0]}), .hex_bcd(1), .seg_7(seg_7), .dp(dp), .com(com));
endmodule

// Down Count Timer
module cook_timer_top (
    input clk, reset_p,
    input [3:0] btn,                                // Input Button
    output [6:0] seg_7,                             // Output FND 7-Segment
    output dp,                                      // Output FND DP
    output [3:0] com,                               // Output FND Digit Select
    output alarm,                                   // Output Alarm
    output [15:0] led                               // Output LED for Debugging
    );

    wire start_set;                                 // State & Mode, Start ↔ Stop & Set
    wire [7:0] sec, min;                            // Time, bcd_to_dec Input Format 12-bit

    wire btn_mode, inc_sec, inc_min, btn_clear;     // Adjusted Button Input
    wire [15:0] sec_bcd, min_bcd;                   // BCD Conversion Format Time

    assign led[0] = start_set;                      // State Output
    assign led[1] = alarm;

    // Button Input Debounce + Prevent Duplicate Processing
    btn_cntr mode_btn (.clk(clk), .reset_p(reset_p), .btn(btn[0]), .btn_pedge(btn_mode));
    btn_cntr inc_sec_btn (.clk(clk), .reset_p(reset_p), .btn(btn[1]), .btn_pedge(inc_sec));
    btn_cntr inc_min_btn (.clk(clk), .reset_p(reset_p), .btn(btn[2]), .btn_pedge(inc_min));
    btn_cntr clear_btn (.clk(clk), .reset_p(reset_p), .btn(btn[3]), .btn_pedge(btn_clear));

    // Using Timer Module, Input Button, Output Time & Mode State
    cook_timer timer_instance (.clk(clk), .reset_p(reset_p),
        .btn_mode(btn_mode), .inc_sec(inc_sec), .inc_min(inc_min), .btn_clear(btn_clear),
        .sec(sec), .min(min), .start_set(start_set), .alarm(alarm));

    // BCD Format Conversion
    bin_to_dec bcd_sec (.bin(sec), .bcd(sec_bcd));
    bin_to_dec bcd_min (.bin(min), .bcd(min_bcd));

    // FND 4-Digit Output
    fnd_cntr fnd (.clk(clk), .reset_p(reset_p),
        .fnd_value({min_bcd[7:0], sec_bcd[7:0]}), .hex_bcd(1), .seg_7(seg_7), .dp(dp), .com(com));
endmodule

// Second Stop Watch + Lap Record
module stop_watch_top (
    input clk, reset_p,
    input [3:0] btn,                                // Input Button
    output [6:0] seg_7,                             // Output FND 7-Segment
    output dp,                                      // Output FND DP
    output [3:0] com,                               // Output FND Digit Select
    output [15:0] led                               // Output LED for Debugging
    );

    wire btn_start, btn_lap, btn_clear;             // Adjusted Button Input
    wire start_stop;                                // Mode, Start ↔ Stop
    wire lap;                                       // Mode, Middle Record ↔ Clear

    wire [7:0] fnd_csec, fnd_sec;
    wire [7:0] csec_bcd, sec_bcd;                   // Conversion BCD Format Time

    assign led[0] = start_stop;                     // Start & Stop State Output
    assign led[1] = lap;                            // Middle Record State Output

    // Button Input Debounce + Prevent Duplicate Processing
    btn_cntr start_btn (.clk(clk), .reset_p(reset_p), .btn(btn[0]), .btn_pedge(btn_start));
    btn_cntr lap_btn (.clk(clk), .reset_p(reset_p), .btn(btn[1]), .btn_pedge(btn_lap));
    btn_cntr clear_btn (.clk(clk), .reset_p(reset_p), .btn(btn[3]), .btn_pedge(btn_clear));

    // Using Stop Watch Module, Input Button, Output Time & Mode State
    stop_watch stop_watch_instance (.clk(clk), .reset_p(reset_p),
        .btn_start(btn_start), .btn_lap(btn_lap), .btn_clear(btn_clear),
        .fnd_csec(fnd_csec), .fnd_sec(fnd_sec), .start_stop(start_stop), .lap(lap));

    // BCD Format Conversion
    bin_to_dec bcd_min (.bin(fnd_csec), .bcd(csec_bcd));
    bin_to_dec bcd_sec (.bin(fnd_sec), .bcd(sec_bcd));

    // FND 4-Digit Output
    fnd_cntr fnd (.clk(clk), .reset_p(reset_p),
        .fnd_value({sec_bcd, csec_bcd}), .hex_bcd(1), .seg_7(seg_7), .dp(dp), .com(com));
endmodule

// Modularization of Key Functions, Elimination of Duplicate Functions
// Watch + Cook Timer + Stop Watch
module watch_collection_top (
    input clk, reset_p,
    input [3:0] btn,                                // Input Button
    input [1:0] sw,                                 // Input Switch, Select Mode
    output [6:0] seg_7,                             // Output FND 7-Segment
    output dp,                                      // Output FND DP
    output [3:0] com,                               // Output FND Digit Select
    output [15:0] led,                              // Output LED for Debugging
    output alarm                                    // Output Alarm
    );

    reg [2:0] mode;                                 // Mode Output, [0] Watch, [1] Timer, [2] Stop Watch
    reg [1:0] led_state;                            // LED Output State
    reg [15:0] fnd_time;                            // FND Output Time
    wire [15:0] bcd_time;                           // BCD Format Time
    wire [3:0] btn_clean;

    // Input & Output Connections for Each Clock
    reg [3:0] btn_w, btn_t, btn_sw;
    wire [15:0] time_w, time_t, time_sw;
    wire [1:0] led_w, led_t, led_sw;

    // Button Input Debounce + Prevent Duplicate Processing
    btn_cntr clean_btn_0 (.clk(clk), .reset_p(reset_p), .btn(btn[0]), .btn_pedge(btn_clean[0]));
    btn_cntr clean_btn_1 (.clk(clk), .reset_p(reset_p), .btn(btn[1]), .btn_pedge(btn_clean[1]));
    btn_cntr clean_btn_2 (.clk(clk), .reset_p(reset_p), .btn(btn[2]), .btn_pedge(btn_clean[2]));
    btn_cntr clean_btn_3 (.clk(clk), .reset_p(reset_p), .btn(btn[3]), .btn_pedge(btn_clean[3]));

    // Using Module, Input Button, Output Time & Mode State
    // Using Watch Module
    watch watch_instance (.clk(clk), .reset_p(reset_p),
        .btn_mode(btn_w[0]), .inc_sec(btn_w[1]), .inc_min(btn_w[2]), .btn_clear(btn_w[3]),
        .sec(time_w[7:0]), .min(time_w[15:8]), .set_watch(led_w[0]));

    // Using Timer Module
    cook_timer timer_instance (.clk(clk), .reset_p(reset_p),
        .btn_mode(btn_t[0]), .inc_sec(btn_t[1]), .inc_min(btn_t[2]), .btn_clear(btn_t[3]),
        .sec(time_t[7:0]), .min(time_t[15:8]), .start_set(led_t[0]), .alarm(led_t[1]));

    // Using Stop Watch Module
    stop_watch stop_watch_instance (.clk(clk), .reset_p(reset_p),
        .btn_start(btn_sw[0]), .btn_lap(btn_sw[1]), .btn_clear(btn_sw[3]),
        .fnd_csec(time_sw[7:0]), .fnd_sec(time_sw[15:8]), .start_stop(led_sw[0]), .lap(led_sw[1]));

    assign led[1:0] = led_state[1:0];               // State Output 1, Varies by Mode
    assign led[15:13] = mode;                       // Mode LED Output
    assign alarm = led_t[1];                        // Alarm Output

    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin                          // Reset = Base Mode
            mode = 3'b000;                          // LED Off
            fnd_time = 0;
        end
        else begin
            case (sw)
                2'd0 : begin                        // Select Watch Mode
                    mode = 3'b001;                  // LED Output LD13
                    btn_w = btn_clean;              // Button Input → Watch Button Input
                    fnd_time = time_w;              // Watch Output → FND Output
                    led_state = led_w;              // Watch Mode → LED Output
                end
                2'd1 : begin                        // Select Cook Timer Mode
                    mode = 3'b010;                  // LED Output LD14
                    btn_t = btn_clean;              // Button Input → Timer Button Input
                    fnd_time = time_t;              // Timer Output → FND Output
                    led_state = led_t;              // Timer Mode → LED Output
                end
                2'd2 : begin                        // Select Stop Watch Mode
                    mode = 3'b100;                  // LED Output LD15
                    btn_sw = btn_clean;             // Button Input → Stop Watch Button Input
                    fnd_time = time_sw;             // Stop Watch Output → FND Output
                    led_state = led_sw;             // Stop Watch Mode → LED Output
                end
                default: begin                      // Default = Base Mode
                    mode = 3'b000;                  // LED Off
                    fnd_time = 0;
                end
            endcase
        end
    end

    // BCD Format Conversion
    bin_to_dec bcd_1 (.bin(fnd_time[7:0]), .bcd(bcd_time[7:0]));
    bin_to_dec bcd_2 (.bin(fnd_time[15:8]), .bcd(bcd_time[15:8]));

    // FND 4-Digit Output
    fnd_cntr fnd (.clk(clk), .reset_p(reset_p),
                .fnd_value(bcd_time), .hex_bcd(1), .seg_7(seg_7), .dp(dp), .com(com));
endmodule

// Modularization of Key Functions, Elimination of Duplicate Functions
// Class Content, Watch + Cook Timer + Stop Watch
module multifunction_watch_top (
    input clk, reset_p,
    input [3:0] btn,                                // Input Button
    output [6:0] seg_7,                             // Output FND 7-Segment
    output dp,                                      // Output FND DP
    output [3:0] com,                               // Output FND Digit Select
    output [15:0] led,                              // Output LED for Debugging
    output alarm                                    // Output Alarm
    );

    localparam WATCH = 0;                           // Mode Constant Define
    localparam COOK_TIMER = 1;
    localparam STOP_WATCH = 2;

    reg [1:0] mode;
    wire btn_mode;                                  // Adjusted Mode Button Input
    wire [2:0] debounced_btn;                       // Adjusted Button Input
    wire [15:0] bin_value, fnd_value;               // FND Output Value, BCD Format

    // Input & Output Connections for Each Clock
    reg [2:0] watch_btn, cook_btn, stop_btn;
    wire [15:0] watch_time, cook_time, stop_time;
    wire [1:0] watch_led, cook_led, stop_led;

    // Button Input Debounce + Prevent Duplicate Processing
    btn_cntr mode_btn (.clk(clk), .reset_p(reset_p), .btn(btn[0]), .btn_pedge(btn_mode));
    btn_cntr btn_de_1 (.clk(clk), .reset_p(reset_p), .btn(btn[1]), .btn_pedge(debounced_btn[0]));
    btn_cntr btn_de_2 (.clk(clk), .reset_p(reset_p), .btn(btn[2]), .btn_pedge(debounced_btn[1]));
    btn_cntr btn_de_3 (.clk(clk), .reset_p(reset_p), .btn(btn[3]), .btn_pedge(debounced_btn[2]));

    // Using Module, Input Button, Output Time & Mode State
    // Using Watch Module
    watch watch_instance (.clk(clk), .reset_p(reset_p),
        .btn_mode(watch_btn[0]), .inc_sec(watch_btn[1]), .inc_min(watch_btn[2]),
        .sec(watch_time[7:0]), .min(watch_time[15:8]), .set_watch(watch_led[0]));

    // Using Timer Module
    cook_timer timer_instance (.clk(clk), .reset_p(reset_p),
        .btn_mode(cook_btn[0]), .inc_sec(cook_btn[1]), .inc_min(cook_btn[2]),// .btn_clear(btn_t[3]),
        .sec(cook_time[7:0]), .min(cook_time[15:8]), .start_set(cook_led[0]), .alarm(cook_led[1]));

    // Using Stop Watch Module
    stop_watch stop_watch_instance (.clk(clk), .reset_p(reset_p),
        .btn_start(stop_btn[0]), .btn_lap(stop_btn[1]), .btn_clear(stop_btn[2]),
        .fnd_csec(stop_time[7:0]), .fnd_sec(stop_time[15:8]), .start_stop(stop_led[0]), .lap(stop_led[1]));

    assign led[15:14] = mode;                       // Mode LED Output
    assign alarm = cook_led[1];                     // Alarm Output

    // Module Output by Mode → FND, LED Output
    assign bin_value = mode == WATCH ? watch_time :
                       mode == COOK_TIMER ? cook_time :
                       mode == STOP_WATCH ? stop_time : watch_time;
    assign led[1:0] = mode == WATCH ? watch_led :
                      mode == COOK_TIMER ? cook_led :
                      mode == STOP_WATCH ? stop_led : watch_led;

    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin                          // Input Reset Button
            mode = WATCH;                           // Base Watch Mode
        end
        else if (btn_mode) begin                    // Input Mode Button → Change Mode
            if (mode == WATCH)              mode = COOK_TIMER;      // Mode Cycling
            else if (mode == COOK_TIMER)    mode = STOP_WATCH;
            else if (mode == STOP_WATCH)    mode = WATCH;
        end
    end

    always @(*) begin
        case (mode)
            WATCH : begin
                watch_btn = debounced_btn;          // Button Input → Watch Button Input
                // cook_btn = 0;
                // stop_btn = 0;
            end
            COOK_TIMER : begin
                // watch_btn = 0;
                cook_btn = debounced_btn;           // Button Input → Timer Button Input
                // stop_btn = 0;
            end
            STOP_WATCH : begin
                // watch_btn = 0;
                // cook_btn = 0;
                stop_btn = debounced_btn;           // Button Input → Watch Button Input
            end
            default : begin
                watch_btn = debounced_btn;          // Default Watch Mode
                // cook_btn = 0;
                // stop_btn = 0;
            end
        endcase
    end

    // BCD Format Conversion
    bin_to_dec bcd_1 (.bin(bin_value[7:0]), .bcd(fnd_value[7:0]));
    bin_to_dec bcd_2 (.bin(bin_value[15:8]), .bcd(fnd_value[15:8]));

    // FND 4-Digit Output
    fnd_cntr fnd (.clk(clk), .reset_p(reset_p),
                .fnd_value(fnd_value), .hex_bcd(1), .seg_7(seg_7), .dp(dp), .com(com));
endmodule

// Humidity & Temperature Measurement, Value Output
module dht11_top (
    input clk, reset_p,
    inout dht11_data,
    output [6:0] seg_7,
    output dp,
    output [3:0] com,
    output [15:0] led
    );

    wire [7:0] humidity, temperature;
    // Using Module, Data Read & Write, Measurement Value Output
    dht11_cntr dht11 (clk, reset_p, dht11_data, humidity, temperature, led);

    wire [7:0] humi_bcd, tmpr_bcd;
    // BCD Format Conversion
    bin_to_dec bcd_humi (.bin(humidity), .bcd(humi_bcd));
    bin_to_dec bcd_tmpr (.bin(temperature), .bcd(tmpr_bcd));

    // FND 4-Digit Output
    fnd_cntr fnd (.clk(clk), .reset_p(reset_p),
                .fnd_value({humi_bcd, tmpr_bcd}), .hex_bcd(1), .seg_7(seg_7), .dp(dp), .com(com));
endmodule

// Distance Measurement, Value Output
module ultrasonic_top (
    input clk, reset_p,
    input ultra_echo,
    output ultra_trig,
    output [6:0] seg_7,
    output dp,
    output [3:0] com,
    output [15:0] led
    );
    
    wire [11:0] distance;
    // Using Module, Data Read & Write, Measurement Distance Value Output
    ultrasonic_cntr ultra (clk, reset_p, ultra_echo, ultra_trig, distance, led);

    wire [15:0] dist_bcd;
    // BCD Format Conversion
    bin_to_dec bcd_dist (.bin(distance), .bcd(dist_bcd));

    // FND 4-Digit Output
    fnd_cntr fnd (.clk(clk), .reset_p(reset_p),
                .fnd_value(dist_bcd), .hex_bcd(1), .seg_7(seg_7), .dp(dp), .com(com));
endmodule
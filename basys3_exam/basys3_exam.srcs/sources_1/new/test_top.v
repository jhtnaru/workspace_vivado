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
    // Data Read & Write, Measurement Distance Value Output
    // Using Module, Connect in Order
    ultrasonic_cntr ultra (clk, reset_p, ultra_echo, ultra_trig, distance, led);

    wire [15:0] dist_bcd;
    // BCD Format Conversion
    bin_to_dec bcd_dist (.bin(distance), .bcd(dist_bcd));

    // FND 4-Digit Output
    fnd_cntr fnd (.clk(clk), .reset_p(reset_p),
                .fnd_value(dist_bcd), .hex_bcd(1), .seg_7(seg_7), .dp(dp), .com(com));
endmodule

// 4 x 4 Keypad Value Output, Left Shift
module keypad_top (
    input clk, reset_p,
    input [3:0] row,
    output [3:0] col,
    output [6:0] seg_7,
    output dp,
    output [3:0] com,
    output [15:0] led
    );
    
    wire [3:0] key_value;
    wire key_valid;
    reg [15:0] fnd_value;
    reg key_flag;                                   // Prevent Duplicate Processing
    keypad_cntr key_pad (clk, reset_p, row, col, key_value, key_valid, led);

    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin
            key_flag = 0;                           // Flag Clear
            fnd_value = 0;                          // FND Value Reset
        end
        else begin
            if (key_valid && !key_flag) begin       // When New Input Occurs
                key_flag = 1;                       // Flag Set
                fnd_value = {fnd_value[11:0], key_value};   // FND Value Left Shift
            end
            else if (!key_valid) begin              // When No Input
                key_flag = 0;                       // Flag Clear
            end
        end
    end

    // FND 4-Digit Output, Hexadecimal
    fnd_cntr fnd (.clk(clk), .reset_p(reset_p),
                .fnd_value(fnd_value), .hex_bcd(1), .seg_7(seg_7), .dp(dp), .com(com));
endmodule

// Display Text on LCD Using I2C Communication, Keypad Input
module i2c_txtlcd_top (
    input clk, reset_p,
    input [3:0] btn,
    input [3:0] row,                            // Input Row Values when Column is High
    output [3:0] col,                           // Output High Values by Changing Column
    output scl, sda,
    output [15:0] led
    );

    wire [3:0] btn_pedge;
    btn_cntr btn0 (clk, reset_p, btn[0], btn_pedge[0]);
    btn_cntr btn1 (clk, reset_p, btn[1], btn_pedge[1]);
    btn_cntr btn2 (clk, reset_p, btn[2], btn_pedge[2]);
    btn_cntr btn3 (clk, reset_p, btn[3], btn_pedge[3]);

    integer cnt_sysclk;
    reg cnt_sysclk_e;
    // System Clock Counter
    always @(negedge clk, posedge reset_p) begin
        if (reset_p) cnt_sysclk = 0;
        else if (cnt_sysclk_e) cnt_sysclk = cnt_sysclk + 1;
        else cnt_sysclk = 0;
    end

    reg [7:0] send_buffer;
    reg send, rs;
    wire busy;
    // Using Module, Byte Unit Transmission
    i2c_lcd_send_byte send_byte (clk, reset_p, 7'h27, send_buffer,
        send, rs, scl, sda, busy, led);
    
    wire [3:0] key_value;                       // Output Values According to Row and Column Inputs
    wire key_valid;                             // Key Input Flag
    keypad_cntr keypad (clk, reset_p, row, col, key_value, key_valid);
    
    // Edge Detection of Keypad Valid
    wire key_valid_pedge;
    edge_detector_pos btn_ed (.clk(clk), .reset_p(reset_p),
        .cp(key_valid), .p_edge(key_valid_pedge));

    // Change State Using Shift
    localparam I2C_IDLE             = 6'b00_0001;   // Standby State
    localparam I2C_INIT             = 6'b00_0010;   // LCD Initialization
    localparam SEND_CHARACTER       = 6'b00_0100;   // Send Each Character to LCD
    localparam SHIFT_RIGHT_DISPLAY  = 6'b00_1000;   // LCD Display Right Shift
    localparam SHIFT_LEFT_DISPLAY   = 6'b01_0000;   // LCD Display Left Shift
    localparam SEND_KEY             = 6'b10_0000;   // Send Keypad Input to LCD

    // Change State in Negative Edge
    reg [5:0] state, next_state;
    always @(negedge clk, posedge reset_p) begin
        if (reset_p) state = I2C_IDLE;
        else state = next_state;
    end

    reg init_flag;                              // LCD Initialization Flag
    reg [10:0] cnt_data;
    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin
            next_state = I2C_IDLE;
            init_flag = 0;
            cnt_sysclk_e = 0;
            send = 0;
            send_buffer = 0;
            rs = 0;
            cnt_data = 0;
        end
        else begin
            case (state)
                I2C_IDLE            : begin     // Standby State
                    if (init_flag) begin        // LCD Initialization Complete
                        // Change State when Button or Keypad Pressed
                        if (btn_pedge[0]) next_state = SEND_CHARACTER;
                        if (btn_pedge[1]) next_state = SHIFT_LEFT_DISPLAY;
                        if (btn_pedge[2]) next_state = SHIFT_RIGHT_DISPLAY;
                        if (key_valid_pedge) next_state = SEND_KEY;
                    end
                    else begin
                        if (cnt_sysclk < 32'd80_000_00) begin   // Wait 80ms
                            cnt_sysclk_e = 1;       // System Clock Count Start
                        end
                        else begin
                            next_state = I2C_INIT;  // Change State I2C_INIT
                            cnt_sysclk_e = 0;       // System Clock Count Stop, Clear
                        end
                    end
                end
                I2C_INIT            : begin         // LCD Initialization
                    if (busy) begin                 // Communicating
                        send = 0;                   // Wait Transmission
                        if (cnt_data >= 6) begin
                            cnt_data = 0;           // LCD Initialization 6-Step Complete
                            next_state = I2C_IDLE;  // Change State I2C_IDLE
                            init_flag = 1;
                        end
                    end
                    else if (!send) begin
                        case (cnt_data)             // Step-by-Step Command Transmission
                            0 : send_buffer = 8'h33;    // Function Set & Function Set
                            1 : send_buffer = 8'h32;    // Function Set & Return Home
                            2 : send_buffer = 8'h28;    // Function Set Data 4-bit, 2-Lines, 5×8 Dots
                            3 : send_buffer = 8'h0C;    // Display On, Cursor Off, Blinking Cursor Off
                            4 : send_buffer = 8'h01;    // Clear Display
                            5 : send_buffer = 8'h06;    // Entry Mode Cursor Move Increment
                        endcase
                        send = 1;                   // Request Transmission
                        cnt_data = cnt_data + 1;    // Step Change
                    end
                end
                SEND_CHARACTER      : begin         // Send Each Character to LCD
                    if (busy) begin                 // Communicating
                        next_state = I2C_IDLE;      // Change State I2C_IDLE
                        send = 0;                   // Wait Transmission
                        if (cnt_data >= 25) cnt_data = 0;   // Send to "z"
                        else cnt_data = cnt_data + 1;   // Next Character
                    end
                    else begin
                        rs = 1;                     // Data Register Select
                        send_buffer = "a" + cnt_data;   // Send in Order from "a"
                        send = 1;                   // Request Transmission
                    end
                end
                SHIFT_RIGHT_DISPLAY : begin         // LCD Display Right Shift
                    if (busy) begin                 // Communicating
                        next_state = I2C_IDLE;      // Change State I2C_IDLE
                        send = 0;                   // Wait Transmission
                    end
                    else begin
                        rs = 0;                     // Instruction Register Select
                        send_buffer = 8'h1C;        // Right Shift Command
                        send = 1;                   // Request Transmission
                    end
                end
                SHIFT_LEFT_DISPLAY  : begin         // LCD Display Left Shift
                    if (busy) begin                 // Communicating
                        next_state = I2C_IDLE;      // Change State I2C_IDLE
                        send = 0;                   // Wait Transmission
                    end
                    else begin
                        rs = 0;                     // Instruction Register Select
                        send_buffer = 8'h18;        // Left Shift Command
                        send = 1;                   // Request Transmission
                    end
                end
                SEND_KEY            : begin         // Send Keypad Input to LCD
                    if (busy) begin                 // Communicating
                        next_state = I2C_IDLE;      // Change State I2C_IDLE
                        send = 0;                   // Wait Transmission
                    end
                    else begin
                        rs = 1;                     // Data Register Select
                        if (key_value < 10) send_buffer = "0" + key_value;
                        else if (key_value == 10) send_buffer = "+";
                        else if (key_value == 11) send_buffer = "-";
                        else if (key_value == 12) send_buffer = " ";
                        else if (key_value == 13) send_buffer = "/";
                        else if (key_value == 14) send_buffer = "*";
                        else if (key_value == 15) send_buffer = "=";
                        send = 1;                   // Request Transmission
                    end
                end
                default             : begin
                    next_state = I2C_IDLE;          // Basic Standby
                    send = 0;                       // Wait Transmission
                end
            endcase
        end
    end
endmodule

//
module i2c_lcdtest_top (
    input clk, reset_p,
    input [3:0] btn,
    output scl, sda,
    output [15:0] led
    );

    wire [3:0] btn_pedge;
    btn_cntr btn0 (clk, reset_p, btn[0], btn_pedge[0]);
    btn_cntr btn1 (clk, reset_p, btn[1], btn_pedge[1]);
    btn_cntr btn2 (clk, reset_p, btn[2], btn_pedge[2]);
    btn_cntr btn3 (clk, reset_p, btn[3], btn_pedge[3]);

    integer cnt_sysclk;
    reg cnt_sysclk_e;
    // System Clock Counter
    always @(negedge clk, posedge reset_p) begin
        if (reset_p) cnt_sysclk = 0;
        else if (cnt_sysclk_e) cnt_sysclk = cnt_sysclk + 1;
        else cnt_sysclk = 0;
    end

    reg [7:0] send_buffer;
    reg send, rs;
    wire busy;
    // Using Module, Byte Unit Transmission
    i2c_lcd_send_byte send_byte (clk, reset_p, 7'h27, send_buffer,
        send, rs, scl, sda, busy, led);
    
    // Change State Using Shift
    localparam I2C_IDLE       = 6'b00_0001;   // Standby State
    localparam I2C_INIT       = 6'b00_0010;   // LCD Initialization
    localparam SEND_CHARACTER = 6'b00_0100;   // Send Each Character to LCD
    localparam SEND_STRING_1  = 6'b00_1000;
    localparam SEND_STRING_2  = 6'b01_0000;
    localparam MOVE_CURSOR    = 6'b10_0000;

    localparam SEND_CHAR = 2'b01;
    localparam WAIT_BUSY = 2'b10;

    // Change State in Negative Edge
    reg [5:0] state, next_state;
    always @(negedge clk, posedge reset_p) begin
        if (reset_p) state = I2C_IDLE;
        else state = next_state;
    end

    reg init_flag;                              // LCD Initialization Flag
    reg move_flag;
    reg [10:0] cnt_data;
    reg [3:0] cnt_string;
    reg [8*16-1:0] str_1;
    reg [8*16-1:0] str_2;
    initial begin
        str_1 = "Hello Vivado !@#";
        str_2 = "LCD Testing 123@";
    end

    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin
            next_state = I2C_IDLE;
            init_flag = 0;
            cnt_sysclk_e = 0;
            send = 0;
            send_buffer = 0;
            rs = 0;
            cnt_data = 0;
            cnt_string = 0;
            move_flag = 1;
        end
        else begin
            case (state)
                I2C_IDLE            : begin     // Standby State
                    if (init_flag) begin        // LCD Initialization Complete
                        // Change State when Button or Keypad Pressed
                        if (btn_pedge[0]) next_state = SEND_CHARACTER;
                        if (btn_pedge[1]) next_state = SEND_STRING_1;
                        if (btn_pedge[2]) next_state = SEND_STRING_2;
                        if (btn_pedge[3]) next_state = MOVE_CURSOR;
                    end
                    else begin
                        if (cnt_sysclk < 32'd80_000_00) begin   // Wait 80ms
                            cnt_sysclk_e = 1;       // System Clock Count Start
                        end
                        else begin
                            next_state = I2C_INIT;  // Change State I2C_INIT
                            cnt_sysclk_e = 0;       // System Clock Count Stop, Clear
                        end
                    end
                end
                I2C_INIT            : begin         // LCD Initialization
                    if (busy) begin                 // Communicating
                        send = 0;                   // Wait Transmission
                        if (cnt_data >= 6) begin
                            cnt_data = 0;           // LCD Initialization 6-Step Complete
                            next_state = I2C_IDLE;  // Change State I2C_IDLE
                            init_flag = 1;
                        end
                    end
                    else if (!send) begin
                        case (cnt_data)             // Step-by-Step Command Transmission
                            0 : send_buffer = 8'h33;    // Function Set & Function Set
                            1 : send_buffer = 8'h32;    // Function Set & Return Home
                            2 : send_buffer = 8'h28;    // Function Set Data 4-bit, 2-Lines, 5×8 Dots
                            3 : send_buffer = 8'h0C;    // Display On, Cursor Off, Blinking Cursor Off
                            4 : send_buffer = 8'h01;    // Clear Display
                            5 : send_buffer = 8'h06;    // Entry Mode Cursor Move Increment
                        endcase
                        send = 1;                   // Request Transmission
                        cnt_data = cnt_data + 1;    // Step Change
                    end
                end
                SEND_CHARACTER      : begin         // Send Each Character to LCD
                    if (busy) begin                 // Communicating
                        next_state = I2C_IDLE;      // Change State I2C_IDLE
                        send = 0;                   // Wait Transmission
                        if (cnt_data >= 25) cnt_data = 0;   // Send to "z"
                        else cnt_data = cnt_data + 1;   // Next Character
                    end
                    else begin
                        rs = 1;                     // Data Register Select
                        send_buffer = "a" + cnt_data;   // Send in Order from "a"
                        send = 1;                   // Request Transmission
                    end
                end
                SEND_STRING_1 : begin         // LCD Display Right Shift
                    if (busy) begin
                        send = 0;
                        if (cnt_string >= 16) begin
                            cnt_string = 0;
                            next_state = I2C_IDLE;
                        end
                    end
                    else if (!send) begin
                        rs = 1;
                        send_buffer = str_1[8*(16-cnt_string)-1 -: 8];
                        send = 1;
                        cnt_string = cnt_string + 1;
                    end
                end
                SEND_STRING_2  : begin
                    if (busy) begin
                        send = 0;
                        next_state = I2C_IDLE;
                        if (cnt_string >= 15) begin
                            cnt_string = 0;
                        end
                        else begin
                            cnt_string = cnt_string + 1;
                        end
                    end
                    else begin
                        rs = 1;
                        send_buffer = str_1[8*(16-cnt_string)-1 -: 8];
                        send = 1;
                    end
                end
                MOVE_CURSOR  : begin
                    if (busy) begin                 // Communicating
                        next_state = I2C_IDLE;      // Change State I2C_IDLE
                        send = 0;                   // Wait Transmission
                    end
                    else begin
                        rs = 0;                     // Instruction Register Select
                        send_buffer = 8'h80;        // Right Shift Command
                        send = 1;                   // Request Transmission
                    end
                end
                default             : begin
                    next_state = I2C_IDLE;          // Basic Standby
                    send = 0;                       // Wait Transmission
                end
            endcase
        end
    end
endmodule

// Controll LED Using PWM Duty Cycle
module led_pwm_top  (
    input clk, reset_p,
    output led_r, led_g, led_b,
    output [15:0] led
    );

    integer cnt_sysclk;
    always @(posedge clk) cnt_sysclk = cnt_sysclk + 1;
    // wire [6:0] duty;
    // assign duty = cnt_sysclk[28:22];

    // Controll LED brightness Using PWM
    wire pwm;
    assign led = {16{pwm}};
    pwm_Nstep #(.duty_step_N(128)) pwm_led (clk, reset_p, cnt_sysclk[28:22], pwm);

    // Adjust RGB LED by Changing Duty Ratio
    pwm_Nstep #(.duty_step_N(150)) pwm_led_r (clk, reset_p, cnt_sysclk[27:20], led_r);
    pwm_Nstep #(.duty_step_N(200)) pwm_led_g (clk, reset_p, cnt_sysclk[28:21], led_g);
    pwm_Nstep #(.duty_step_N(256)) pwm_led_b (clk, reset_p, cnt_sysclk[29:22], led_b);
endmodule

// Servo Motor Control Using PWM
module sg90_top (
    input clk, reset_p,
    input [3:0] btn,
    output sg90,
    output [6:0] seg_7,
    output dp,
    output [3:0] com,
    output [15:0] led
    );

    wire [3:0] btn_pedge;
    btn_cntr btn0 (clk, reset_p, btn[0], btn_pedge[0]);
    btn_cntr btn1 (clk, reset_p, btn[1], btn_pedge[1]);
    btn_cntr btn2 (clk, reset_p, btn[2], btn_pedge[2]);
    btn_cntr btn3 (clk, reset_p, btn[3], btn_pedge[3]);

    integer cnt_sysclk;
    always @(posedge clk) cnt_sysclk = cnt_sysclk + 1;

    // Edge Detection of
    wire cnt_sysclk_pedge;
    edge_detector_pos btn_ed (.clk(clk), .reset_p(reset_p),
        .cp(cnt_sysclk[21]), .p_edge(cnt_sysclk_pedge));

    integer step;
    reg inc_flag, mode;
    assign led[15] = mode;
    // Change Mode by Pressing Button
    always @(posedge clk, posedge reset_p) begin
        if (reset_p) mode = 1;
        else if(btn_pedge[0]) mode = ~mode;
    end

    // Reciprocation
    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin
            step = 40;
            inc_flag = 1;
        end
        else if (mode) begin
            if (cnt_sysclk_pedge) begin
                if (inc_flag) begin         // Reciprocating Motion According to Direction Flag
                    if (step >= 210) inc_flag = 0;
                    else step = step + 1;
                end
                else begin
                    if (step <= 40) inc_flag = 1;
                    else step = step - 1;
                end
            end
        end
        else if (!mode) begin               // Pressing Button Increases or Decreases Value
            if (btn_pedge[1]) begin
                step = step - 1;
            end
            else if (btn_pedge[2]) begin
                step = step + 1;
            end
        end
    end

    // Frequency and Step Settings, Step Max 640, Move 82 ~ 14
    pwm_Nstep #(.pwm_freq(50), .duty_step_N(1670))
        pwm_sg90 (clk, reset_p, step, sg90);

    // FND 4-Digit Output
    fnd_cntr fnd (.clk(clk), .reset_p(reset_p),
                .fnd_value(step [11:0]), .hex_bcd(0), .seg_7(seg_7), .dp(dp), .com(com));
endmodule

// Input 1-Channel ADC Value from Variable Resistor or Photo Sensor
module adc_top_6 (
    input clk, reset_p,
    input vauxp6, vauxn6,
    output [6:0] seg_7,
    output dp,
    output [3:0] com,
    output [15:0] led
    );

    wire [4:0] channel_out;
    wire [15:0] do_out;                     // do_out 16-bit, but Actual Value 12-bit
    wire eoc_out;
    xadc_wiz_0 adc (                        // Use of Registered IP Module
        .daddr_in({2'b00, channel_out}),    // Address bus for the dynamic reconfiguration port
        .dclk_in(clk),                      // Clock input for the dynamic reconfiguration port
        .den_in(eoc_out),                   // Enable Signal for the dynamic reconfiguration port
        .reset_in(reset_p),                 // Reset signal for the System Monitor control logic
        .vauxp6(vauxp6), .vauxn6(vauxn6),   // Auxiliary channel 6
        .channel_out(channel_out),          // Channel Selection Outputs
        .do_out(do_out),                    // Output data bus for dynamic reconfiguration port
        .eoc_out(eoc_out)                   // End of Conversion Signal
        );
        // eos_out End of Sequence Signal - If Multiple Channels, End All Channels

    // Edge Detection of EOC
    wire eoc_pedge;
    edge_detector_pos eoc_ed (.clk(clk), .reset_p(reset_p),
        .cp(eoc_out), .p_edge(eoc_pedge));

    reg [11:0] adc_value;
    always @(posedge clk, posedge reset_p) begin
        if (reset_p) adc_value = 0;
        else if (eoc_pedge) adc_value = do_out[15:4];
        // else if (eoc_pedge) adc_value = do_out[15:8];       // Discard Lower-bits More Stable
    end

    // FND 4-Digit Output
    fnd_cntr fnd (.clk(clk), .reset_p(reset_p),
                .fnd_value(adc_value), .hex_bcd(0), .seg_7(seg_7), .dp(dp), .com(com));
endmodule

// Input 2-Channel ADC Value from Joystick
module adc_sequence2_top (
    input clk, reset_p,
    input vauxp6, vauxn6,                       // XA1
    input vauxp14, vauxn14,                     // XA2
    output [6:0] seg_7,
    output dp,
    output [3:0] com,
    output led_r, led_g, led_b,
    output [15:0] led
    );

    wire [4:0] channel_out;
    wire [15:0] do_out;                         // do_out 16-bit, but Actual Value 12-bit
    wire eoc_out;
    xadc_joystick joystick_adc (                // Use of Registered IP Module
        .daddr_in({2'b00, channel_out}),        // Address bus for the dynamic reconfiguration port
        .dclk_in(clk),                          // Clock input for the dynamic reconfiguration port
        .den_in(eoc_out),                       // Enable Signal for the dynamic reconfiguration port
        .reset_in(reset_p),                     // Reset signal for the System Monitor control logic
        .vauxp6(vauxp6), .vauxn6(vauxn6),       // Auxiliary channel 6
        .vauxp14(vauxp14), .vauxn14(vauxn14),   // Auxiliary channel 14
        .channel_out(channel_out),              // Channel Selection Outputs
        .do_out(do_out),                        // Output data bus for dynamic reconfiguration port
        .eoc_out(eoc_out)                       // End of Conversion Signal
        );

    // Edge Detection of EOC
    wire eoc_pedge;
    edge_detector_pos eoc_ed (.clk(clk), .reset_p(reset_p),
        .cp(eoc_out), .p_edge(eoc_pedge));

    reg [11:0] adc_value_x, adc_value_y;
    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin
            adc_value_x = 0;
            adc_value_y = 0;
        end
        else if (eoc_pedge) begin
            case (channel_out[3:0])
                6  : adc_value_x = do_out[15:4];
                14 : adc_value_y = do_out[15:4];
            endcase
        end
    end

    wire [7:0] adcx_bcd, adcy_bcd;
    // BCD Format Conversion
    bin_to_dec bcd_adcx (.bin(adc_value_x[11:6]), .bcd(adcx_bcd));  // Discard Lower-bits More Stable
    bin_to_dec bcd_adcy (.bin(adc_value_y[11:6]), .bcd(adcy_bcd));

    // FND 4-Digit Output
    fnd_cntr fnd (.clk(clk), .reset_p(reset_p),
                .fnd_value({adcx_bcd, adcy_bcd}), .hex_bcd(1), .seg_7(seg_7), .dp(dp), .com(com));

    // Get Joystick ADC Value and Control LED
    pwm_Nstep #(.duty_step_N(128)) pwm_led_g (clk, reset_p, adc_value_x[11:5], led_r);
    pwm_Nstep #(.duty_step_N(128)) pwm_led_b (clk, reset_p, adc_value_y[11:5], led_b);
endmodule

//
module fnd_direct_top (
    input clk, reset_p,
    output [6:0] seg_7,
    output dp,
    output [3:0] com,
    output [15:0] led
    );

    integer cnt_sysclk;
    // System Clock Counter
    always @(negedge clk, posedge reset_p) begin
        if (reset_p) cnt_sysclk <= 0;
        else cnt_sysclk <= cnt_sysclk + 1;
    end
    
    // Edge Detection of
    wire cnt_sysclk_pedge;
    edge_detector_pos eoc_ed (.clk(clk), .reset_p(reset_p),
        .cp(cnt_sysclk[25]), .p_edge(cnt_sysclk_pedge));

    reg [31:0] fnd_value;

    reg [3:0] cnt_data;
    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin
            cnt_data <= 0;
        end
        else if (cnt_sysclk_pedge) begin
            if (cnt_data >= 11) cnt_data <= 0;
            else cnt_data <= cnt_data + 1;
        end
    end

    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin
            fnd_value <= 32'hFF_FF_FF_FF & ~(32'b1 << 0);
        end
        else begin
            case (cnt_data)
                4'd0    : fnd_value <= 32'hFF_FF_FF_FF & ~(32'b1 << 0);
                4'd1    : fnd_value <= 32'hFF_FF_FF_FF & ~(32'b1 << 1);
                4'd2    : fnd_value <= 32'hFF_FF_FF_FF & ~(32'b1 << 2);
                4'd3    : fnd_value <= 32'hFF_FF_FF_FF & ~(32'b1 << 3);
                4'd4    : fnd_value <= 32'hFF_FF_FF_FF & ~(32'b1 << 11);
                4'd5    : fnd_value <= 32'hFF_FF_FF_FF & ~(32'b1 << 19);
                4'd6    : fnd_value <= 32'hFF_FF_FF_FF & ~(32'b1 << 27);
                4'd7    : fnd_value <= 32'hFF_FF_FF_FF & ~(32'b1 << 28);
                4'd8    : fnd_value <= 32'hFF_FF_FF_FF & ~(32'b1 << 29);
                4'd9    : fnd_value <= 32'hFF_FF_FF_FF & ~(32'b1 << 24);
                4'd10   : fnd_value <= 32'hFF_FF_FF_FF & ~(32'b1 << 16);
                4'd11   : fnd_value <= 32'hFF_FF_FF_FF & ~(32'b1 << 8);
                default : fnd_value <= 32'hFF_FF_FF_FF & ~(32'b1 << 0);
            endcase
        end
    end

    // reg [3:0] digit_in;
    // wire [6:0] seg_out;
    // reg [6:0] fnd_seg_1, fnd_seg_2, fnd_seg_3, fnd_seg_4;
    // seg_decoder_a (2'b1, digit_in, seg_out);

    // always @(posedge clk, posedge reset_p) begin
    //     if (reset_p) begin
    //         digit_in <= 0;
    //         fnd_seg_1 <= seg_out;
    //         fnd_seg_2 <= seg_out;
    //         fnd_seg_3 <= seg_out;
    //         fnd_seg_4 <= seg_out;
    //     end
    //     else if (cnt_sysclk_pedge) begin
    //         if (digit_in == 9) begin
    //             digit_in <= 0;
    //         end
    //         else begin
    //             digit_in <= digit_in + 1;
    //         end
    //         fnd_seg_1 <= fnd_seg_2;
    //         fnd_seg_2 <= fnd_seg_3;
    //         fnd_seg_3 <= fnd_seg_4;
    //         fnd_seg_4 <= seg_out;
    //     end
    // end

    // assign fnd_value = {1'b1, fnd_seg_1, 1'b1, fnd_seg_2, 1'b1, fnd_seg_3, 1'b1, fnd_seg_4};
    fnd_cntr_direct_a fnd (clk, reset_p, fnd_value, seg_7, dp, com);
endmodule

//
module sensor_cnt_top (
    input clk, reset_p,
    input sensor,
    output [6:0] seg_7,
    output dp,
    output [3:0] com,
    output [15:0] led
    );

    wire sensor_pedge, sensor_nedge;
    // btn_cntr sensor_btn (clk, reset_p, sensor, sensor_pedge, sensor_nedge);
    edge_detector_pos sensor_ed (clk, reset_p, sensor, sensor_pedge, sensor_ndege);

    reg led_sensor;
    reg [11:0] cnt_pedge, cnt_nedge;
    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin
            cnt_pedge <= 0;
            cnt_nedge <= 0;
        end
        else if (sensor_pedge) begin
            cnt_pedge <= cnt_pedge + 1;
        end
        else if (sensor_nedge) begin
            cnt_nedge <= cnt_nedge + 1;
        end
    end

    wire led_state;
    assign led_state = ~sensor;
    assign led[3:0] = {4{sensor}};
    assign led[7:4] = {4{led_state}};

    wire [7:0] pedge_bcd, nedge_bcd;
    // BCD Format Conversion
    bin_to_dec bcd_pe (.bin(cnt_pedge), .bcd(pedge_bcd));  // Discard Lower-bits More Stable
    bin_to_dec bcd_ne (.bin(cnt_nedge), .bcd(nedge_bcd));

    // FND 4-Digit Output
    fnd_cntr fnd (.clk(clk), .reset_p(reset_p),
        .fnd_value({pedge_bcd, nedge_bcd}), .hex_bcd(1), .seg_7(seg_7), .dp(dp), .com(com));
endmodule


module sensor_test_top (
    input clk, reset_p,
    input sensor,
    output [15:0] led
    );

    wire led_state;
    assign led_state = ~sensor;
    assign led[3:0] = {4{sensor}};
    assign led[7:4] = {4{led_state}};
endmodule

//
module fan_motor_top (
    input clk, reset_p,
    input [3:0] btn,
    output reg fan,
    output [6:0] seg_7,
    output dp,
    output [3:0] com,
    output [15:0] led
    );

    wire [3:0] btn_pedge;
    btn_cntr btn0 (clk, reset_p, btn[0], btn_pedge[0]);
    btn_cntr btn1 (clk, reset_p, btn[1], btn_pedge[1]);
    btn_cntr btn2 (clk, reset_p, btn[2], btn_pedge[2]);
    btn_cntr btn3 (clk, reset_p, btn[3], btn_pedge[3]);

    reg fan_mode;
    assign led[0] = fan_mode;
    assign led[1] = fan;
    always @(posedge clk, posedge reset_p) begin
        if (reset_p) fan_mode <= 0;
        else if (btn_pedge[0]) fan_mode <= ~fan_mode;
    end

    reg [7:0] fan_duty;
    wire fan_pwm;
    pwm_Nstep pwm_fan (clk, reset_p, fan_duty, fan_pwm);

    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin
            fan <= 0;
        end
        else if (!fan_mode) begin
            if (btn_pedge[1]) fan <= 0;
            else if (btn_pedge[2]) fan <= 1;
        end
        else begin
            fan <= fan_pwm;
        end
    end

    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin
            fan_duty <= 0;
        end
        else if (btn_pedge[1]) begin
            if (fan_duty <= 5) fan_duty <= 0;
            else fan_duty = fan_duty - 5;
        end
        else if (btn_pedge[2]) begin
            if (fan_duty <= 195) fan_duty <= 195;
            else fan_duty = fan_duty + 5;
        end
    end

    // FND 4-Digit Output
    fnd_cntr fnd (.clk(clk), .reset_p(reset_p),
        .fnd_value(speed), .hex_bcd(0), .seg_7(seg_7), .dp(dp), .com(com));
endmodule

module rtc_test_top (
    input clk, reset_p,
    input [3:0] btn,
    inout rtc_dat,
    output rtc_clk, rtc_rst,
    output [6:0] seg_7,
    output dp,
    output [3:0] com,
    output [15:0] led
    );
    
    reg read_en;
    wire [7:0] sec, min, hour;
    wire [7:0] date, month, day, year;
    wire data_valid, busy;
    rtc_read_cntr rtc_read (.clk(clk), .reset_p(reset_p),
        .read_en(read_en), .rtc_dat(rtc_dat), .rtc_clk(rtc_clk), .rtc_rst(rtc_rst),
        .sec(sec), .min(min), .hour(hour), .date(date), .month(month), .day(day), .year(year),
        .data_valid(data_valid), .busy(busy));

    wire [3:0] btn_pedge;
    btn_cntr btn0 (clk, reset_p, btn[0], btn_pedge[0]);
    btn_cntr btn1 (clk, reset_p, btn[1], btn_pedge[1]);
    btn_cntr btn2 (clk, reset_p, btn[2], btn_pedge[2]);
    btn_cntr btn3 (clk, reset_p, btn[3], btn_pedge[3]);

    wire [15:0] fnd_value;
    reg [1:0] fnd_cnt;

    assign led[7:0] = hour;
    assign led[15:8] = date;
    assign fnd_value = {min, sec};
    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin
            read_en <= 0;
            fnd_cnt <= 0;
        end
        else begin
            if (btn_pedge[0] && !busy) read_en <= 1;
            if (data_valid) read_en <= 0;
            if (btn_pedge[1]) begin
                if (fnd_cnt >= 2) fnd_cnt <= 0;
                else fnd_cnt <= fnd_cnt + 1;
            end
        end
    end

    // FND 4-Digit Output
    fnd_cntr fnd (.clk(clk), .reset_p(reset_p),
        .fnd_value(fnd_value), .hex_bcd(1), .seg_7(seg_7), .dp(dp), .com(com));
endmodule

module stepper_test_top (
    input clk, reset_p,
    input [3:0] btn,
    output [3:0] step_out,
    output [15:0] led
    );

    wire [3:0] btn_pedge;
    btn_cntr btn0 (clk, reset_p, btn[0], btn_pedge[0]);
    btn_cntr btn1 (clk, reset_p, btn[1], btn_pedge[1]);
    btn_cntr btn2 (clk, reset_p, btn[2], btn_pedge[2]);
    btn_cntr btn3 (clk, reset_p, btn[3], btn_pedge[3]);

    reg [4:0] step_mode;
    reg step_start;
    reg [11:0] step_angle;
    reg step_dir;
    stepper_cntr stepby (.clk(clk), .reset_p(reset_p),
        .step_mode(step_mode), .step_start(step_start), .step_angle(step_angle), .step_dir(step_dir),
        .step_out(step_out));
    
    assign led[0] = step_start;
    assign led[1] = step_dir;
    assign led[6:2] = step_mode;
    assign led[10:7] = step_acnt;

    reg [3:0] step_acnt = 1;
    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin
            step_mode <= 4'b0001;
            step_start <= 0;
            step_angle <= 90;
            step_dir <= 1;
            step_acnt <= 1;
        end
        else begin
            if (btn_pedge[0]) begin
                step_start <= ~step_start;
            end
            else if (btn_pedge[1]) begin
                if (step_mode == 5'b10000) step_mode <= 5'b00001;
                else step_mode <= step_mode << 1;
            end
            else if (btn_pedge[2]) begin
                step_dir <= ~step_dir;
            end
            else if (btn_pedge[3]) begin
                if (step_angle >= 720) begin
                    step_angle <= 90;
                    step_acnt <= 1;
                end
                else begin
                    step_angle <= step_angle + 90;
                    step_acnt <= step_acnt + 1;
                end
            end
        end
    end
endmodule

//
module fan_test_top (
    input clk, reset_p,
    input [3:0] btn,
    output [1:0] fan_out,
    output [6:0] seg_7,
    output dp,
    output [3:0] com,
    output [15:0] led
    );

    wire [3:0] btn_pedge;
    btn_cntr btn0 (clk, reset_p, btn[0], btn_pedge[0]);
    btn_cntr btn1 (clk, reset_p, btn[1], btn_pedge[1]);
    btn_cntr btn2 (clk, reset_p, btn[2], btn_pedge[2]);
    btn_cntr btn3 (clk, reset_p, btn[3], btn_pedge[3]);

    reg [2:0] fan_mode = 3'b001;
    reg fan_start = 0;
    reg fan_dir = 1;
    reg [7:0] fan_duty = 100;
    fan_cntr fan_motor (.clk(clk), .reset_p(reset_p),
        .fan_mode(fan_mode), .fan_start(fan_start), .fan_dir(fan_dir),
        .fan_duty(fan_duty), .fan_out(fan_out));
    
    assign led[0] = fan_start;
    assign led[1] = fan_dir;
    assign led[4:2] = fan_mode;
    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin
            fan_mode <= 3'b001;
            fan_start <= 0;
            fan_dir <= 1;
            fan_duty <= 100;
        end
        else begin
            if (btn_pedge[0]) begin
                fan_start <= ~fan_start;
            end
            else if (btn_pedge[1]) begin
                if (fan_mode == 3'b100) fan_mode <= 3'b001;
                else fan_mode <= fan_mode << 1;
            end
            else if (btn_pedge[2]) begin
                fan_dir <= ~fan_dir;
            end
            else if (btn_pedge[3]) begin
                if (fan_duty >= 250) fan_duty <= 100;
                else fan_duty <= fan_duty + 10;
            end
        end
    end

    // FND 4-Digit Output
    fnd_cntr fnd (.clk(clk), .reset_p(reset_p),
        .fnd_value(fan_duty), .hex_bcd(0), .seg_7(seg_7), .dp(dp), .com(com));
endmodule


module basic_top (
    input clk, reset_p,
    input [15:0] sw,
    input [3:0] btn,
    output [6:0] seg_7,
    output reg dp,
    output [3:0] com,
    output [15:0] led
    );

    wire [3:0] btn_pedge, btn_nedge;
    btn_cntr btn0 (clk, reset_p, btn[0], btn_pedge[0], btn_nedge[0]);
    btn_cntr btn1 (clk, reset_p, btn[1], btn_pedge[1], btn_nedge[1]);
    btn_cntr btn2 (clk, reset_p, btn[2], btn_pedge[2], btn_nedge[2]);
    btn_cntr btn3 (clk, reset_p, btn[3], btn_pedge[3], btn_nedge[3]);

    assign led = sw;

    integer cnt_sysclk;
    reg cnt_sysclk_e;
    reg [15:0] cnt_fnd;
    reg [1:0] cnt_dp;
    reg [3:0] dp_in;
    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin
            cnt_sysclk_e <= 1;
            cnt_sysclk <= 0;
            cnt_fnd <= 0;
            dp <= 1'b1;
            dp_in <= 4'b1111;
        end
        else if (btn_pedge[0]) cnt_sysclk_e <= ~cnt_sysclk_e;
        else if (btn_pedge[1]) begin
            if (cnt_fnd[7:4] >= 4'd9) begin
                cnt_fnd[7:4] <= 0;
            end
            else begin
                cnt_fnd[7:4] <= cnt_fnd[7:4] + 1;
            end 
        end
        else if (btn_pedge[2]) begin
            if (cnt_fnd[11:8] >= 4'd9) begin
                cnt_fnd[11:8] <= 0;
            end
            else begin
                cnt_fnd[11:8] <= cnt_fnd[11:8] + 1;
            end 
        end
        else if (btn_pedge[3]) begin
            if (cnt_fnd[15:12] >= 4'd9) begin
                cnt_fnd[15:12] <= 0;
            end
            else begin
                cnt_fnd[15:12] <= cnt_fnd[15:12] + 1;
            end 
        end
        else begin
            if (cnt_sysclk_e) begin
                if (cnt_sysclk >= 99_999_999) begin
                    cnt_sysclk <= 0;
                    cnt_dp <= cnt_dp + 1;
                    if (cnt_fnd[3:0] >= 4'd9) begin
                        cnt_fnd[3:0] <= 0;
                        if (cnt_fnd[7:4] >= 4'd9) begin
                            cnt_fnd[7:4] <= 0;
                            if (cnt_fnd[11:8] >= 4'd9) begin
                                cnt_fnd[11:8] <= 0;
                                if (cnt_fnd[15:12] >= 4'd9) begin
                                    cnt_fnd[15:12] <= 0;
                                end
                                else begin
                                    cnt_fnd[15:12] <= cnt_fnd[15:12] + 1;
                                end
                            end
                            else begin
                                cnt_fnd[11:8] <= cnt_fnd[11:8] + 1;
                            end
                        end
                        else begin
                            cnt_fnd[7:4] <= cnt_fnd[7:4] + 1;
                        end
                    end
                    else begin
                        cnt_fnd[3:0] <= cnt_fnd[3:0] + 1;
                    end
                end
                else cnt_sysclk <= cnt_sysclk + 1;
            end
            else begin
                cnt_sysclk <= 0;
            end
            case (cnt_dp)
                2'd0   : dp_in <= 4'b1110;
                2'd1   : dp_in <= 4'b1101;
                2'd2   : dp_in <= 4'b1011;
                2'd3   : dp_in <= 4'b0111;
                default: dp_in <= 4'b1111;
            endcase
            case (com)
                4'b1110 : dp <= dp_in[0];
                4'b1101 : dp <= dp_in[1];
                4'b1011 : dp <= dp_in[2];
                4'b0111 : dp <= dp_in[3];
                default : dp <= 1'b1;
            endcase
        end
    end

    fnd_cntr fnd (.clk(clk), .reset_p(reset_p),
        .fnd_value(cnt_fnd), .hex_bcd(1), .seg_7(seg_7), .dp(), .com(com));
endmodule
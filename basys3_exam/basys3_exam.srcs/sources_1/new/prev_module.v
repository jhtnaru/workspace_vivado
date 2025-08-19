`timescale 1ns / 1ps

// Watch + Cook Timer + Stop Watch
module watch_collection_top_v01 (
    input clk, reset_p,
    input [3:0] btn,                                // Input Button
    input [1:0] sw,                                 // Input Switch, Select Mode
    output reg [6:0] seg_7,                         // Output FND 7-Segment
    output reg dp,                                  // Output FND DP
    output reg [3:0] com,                           // Output FND Digit Select
    output [15:0] led,                              // Output LED for Debugging
    output alarm                                    // Output Alarm
    );

    reg [3:0] mode;                                 // Mode Output, [0] Base, [1] Watch, [2] Timer, [3] Stop Watch
    reg led_0, led_1;                               // for State LED Output
    reg [15:0] base_time;                           // for Mode Base FND Output

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
    cook_timer_top timer (.clk(clk), .reset_p(reset_p), .btn(btn_t),
                    .seg_7(seg_t), .dp(dp_t), .com(com_t), .alarm(alarm_t), .led(led_t));

    // Stop Watch Connect using _sw
    stop_watch_top swatch (.clk(clk), .reset_p(reset_p), .btn(btn_sw),
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
                2'd0 : begin                        // Select Watch Mode
                    mode = 4'b0010;                 // LED Output LD13
                    btn_w = btn[2:0];               // Button Input → Watch Button Input
                    seg_7 = seg_w;                  // Watch Output → FND Output
                    dp = dp_w;
                    com = com_w;
                    led_0 = led_w[0];               // Watch Start & Set State Output
                    led_1 = led_w[1];
                end
                2'd1 : begin                        // Select Cook Timer Mode
                    mode = 4'b0100;                 // LED Output LD14
                    btn_t = btn;                    // Button Input → Timer Button Input
                    seg_7 = seg_t;                  // Timer Output → FND Output
                    dp = dp_t;
                    com = com_t;
                    led_0 = led_t[0];               // Timer Start & Stop State Output
                    led_1 = led_t[1];               // Timer Alarm On ↔ Off Output
                end
                2'd2 : begin                        // Select Stop Watch Mode
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

// Class Content, Watch + Cook Timer + Stop Watch
module multifunction_watch_top_v01 (
    input clk, reset_p,
    input [3:0] btn,
    output [6:0] seg_7,
    output dp,
    output [3:0] com,
    output alarm,
    output [15:0] led
    );

    localparam WATCH = 0;
    localparam COOK_TIMER = 1;
    localparam STOP_WATCH = 2;

    reg [1:0] mode;
    wire btn_mode;

    reg [2:0] watch_btn, cook_btn, stop_btn;
    wire [6:0] watch_seg_7, cook_seg_7, stop_seg_7;
    wire watch_dp, cook_dp, stop_dp;
    wire [3:0] watch_com, cook_com, stop_com;

    watch_top watch (.clk(clk), .reset_p(reset_p),
        .btn(watch_btn), .seg_7(watch_seg_7), .dp(watch_dp), .com(watch_com));
    cook_timer_top timer (.clk(clk), .reset_p(reset_p),
        .btn(cook_btn), .seg_7(cook_seg_7), .dp(cook_dp), .com(cook_com), .alarm(alarm));
    stop_watch_top stop (.clk(clk), .reset_p(reset_p),
        .btn(stop_btn), .seg_7(stop_seg_7), .dp(stop_dp), .com(stop_com));

    btn_cntr mode_btn (.clk(clk), .reset_p(reset_p), .btn(btn[0]), .btn_pedge(btn_mode));

    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin
            mode = WATCH;
        end
        else if (btn_mode) begin
            if (mode == WATCH)              mode = COOK_TIMER;
            else if (mode == COOK_TIMER)    mode = STOP_WATCH;
            else if (mode == STOP_WATCH)    mode = WATCH;
        end
    end

    always @(*) begin
        case (mode)
            WATCH : begin
                watch_btn = btn[3:1];
                cook_btn = 0;
                stop_btn = 0;
            end
            COOK_TIMER : begin
                watch_btn = 0;
                cook_btn = btn[3:1];
                stop_btn = 0;
            end
            STOP_WATCH : begin
                watch_btn = 0;
                cook_btn = 0;
                stop_btn = btn[3:1];
            end
            default : begin
                watch_btn = btn[3:1];
                cook_btn = 0;
                stop_btn = 0;
            end
        endcase
    end

    assign seg_7 = mode == WATCH ? watch_seg_7 :
                   mode == COOK_TIMER ? cook_seg_7 :
                   mode == STOP_WATCH ? stop_seg_7 : watch_seg_7;
    assign dp = mode == WATCH ? watch_dp :
                mode == COOK_TIMER ? cook_dp :
                mode == STOP_WATCH ? stop_dp : watch_dp;
    assign com = mode == WATCH ? watch_com :
                 mode == COOK_TIMER ? cook_com :
                 mode == STOP_WATCH ? stop_com : watch_com;

    assign led[1:0] = mode;
    assign led[15] = alarm;
endmodule

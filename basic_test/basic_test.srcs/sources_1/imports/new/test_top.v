`timescale 1ns / 1ps

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

// 기본
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
        else if (btn_pedge[1]) cnt_fnd[7:4] <= cnt_fnd[7:4] + 1;
        else if (btn_pedge[2]) cnt_fnd[11:8] <= cnt_fnd[11:8] + 1;
        else if (btn_pedge[3]) cnt_fnd[15:12] <= cnt_fnd[15:12] + 1;
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

//
module port_test_top(
    input clk, reset_p,
    input [15:0] sw,
    input [3:0] btn,
    output [7:0] JA,
    output [6:0] seg_7,
    output dp,
    output [3:0] com,
    output [15:0] led
    );

    assign led = sw;
    assign JA = sw [7:0];
endmodule

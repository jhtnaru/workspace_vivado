`timescale 1ns / 1ps

// FND 4-Digit Output
module fnd_cntr (
    input clk, reset_p,
    input [15:0] fnd_value,
    input hex_bcd,
    output [6:0] seg_7,
    output dp,
    output [3:0] com
    );

    wire [15:0] bcd_value;
    // Convert Input Value to BCD Format
    bin_to_dec bcd (.bin(fnd_value[11:0]), .bcd(bcd_value));

    reg [16:0] clk_div;             // Clock Divide

    always @(posedge clk) begin
        clk_div = clk_div + 1;
    end

    // Change FND Output Every 2^16 * 10ns 
    anode_selector ring_com (.scan_count(clk_div[16:15]), .an_out(com));

    reg [3:0] digit_value;          // Single-Digit Output Value

    wire [15:0] out_value;          // Hex ↔ BCD Change Format
    assign out_value = hex_bcd ? fnd_value : bcd_value;

    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin          // Single-Digit Value Reset
            digit_value = 0;
        end
        else begin
            case (com)              // Select Digit Value
                4'b1110 : digit_value = out_value[3:0];
                4'b1101 : digit_value = out_value[7:4];
                4'b1011 : digit_value = out_value[11:8];
                4'b0111 : digit_value = out_value[15:12];
                default : digit_value = 0;
            endcase
        end
    end

    seg_decoder_a dec (.scan_count(clk_div[16:15]), .digit_in(digit_value),
                    .seg_out(seg_7), .dp_out(dp));
endmodule

// Button Debounce 
module button_debounce (
    input clk,
    input noise_btn,            // Raw Input Button
    output reg clean_btn        // Modify Button
    );

    reg [19:0] cnt = 1;
    reg btn_sync_0, btn_sync_1; // 2 Step Debounce
    reg btn_state;              // Button Before State

    always @(posedge clk) begin
        btn_sync_0 <= noise_btn;
        btn_sync_1 <= btn_sync_0;
    end

    always @(posedge clk) begin
        if (btn_sync_1 == btn_state) begin
            cnt <= 1;           // Input == Before State, Stable State → Counter Reset
        end
        else begin
            cnt <= cnt + 1;     // Input != Before State, Count Increase
            if (cnt >= 1_000_000) begin  // Maintain a Specific Time for Debounce, 10ns * 1,000,000 = 10ms
                btn_state <= btn_sync_1;
                clean_btn <= btn_sync_1;
                cnt <= 1;
            end
        end
    end
endmodule

// Button Debounce + Edge Detect, Switch also Available
module btn_cntr (
    input clk, reset_p,
    input btn,
    output btn_pedge, btn_ndege
    );

    wire debounced_btn;
    button_debounce btn_debounce (.clk(clk), .noise_btn(btn), .clean_btn(debounced_btn));
    edge_detector_pos btn_ed (.clk(clk), .reset_p(reset_p),
        .cp(debounced_btn), .p_edge(btn_pedge), .n_edge(btn_ndege));
endmodule

// Watch Module, Second & Minute, Set Increase & Count
module watch (
    input clk, reset_p,
    input btn_mode, inc_sec, inc_min, btn_clear,    // Input Button
    output reg [7:0] sec, min,                      // Output Time
    output reg set_watch                            // Output State
    );

    reg [26:0] cnt_sysclk;                          // Clock Division

    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin                          // Mode Reset
            set_watch = 0;                          // Start Mode
        end
        else if (btn_mode) begin
            set_watch = ~set_watch;                 // Mode Toggle, Start ↔ Set
        end
    end

    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin                          // Time Reset
            cnt_sysclk = 1;
            sec = 0;
            min = 0;
        end
        else begin
            if (set_watch) begin                    // Set Mode
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
                cnt_sysclk = cnt_sysclk + 1;        // Count for Clock Division
            end
            if (btn_clear) begin
                cnt_sysclk = 1;
                sec = 0;
                min = 0;
            end
        end
    end
endmodule

// Timer Module, Set Time & Down Count, Alarm when Time Up
module cook_timer (
    input clk, reset_p,
    input btn_mode, inc_sec, inc_min, btn_clear,
    output reg [7:0] sec, min,
    output reg start_set, alarm
    );

    reg [26:0] cnt_sysclk;                          // Clock Division Count
    reg [7:0] set_sec, set_min;
    reg set_flag;                                   // Alarm Off Flag

    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin                          // State Reset
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
        else if (alarm && (inc_sec || inc_min || btn_mode)) begin
            alarm = 0;                              // Alarm Off
            set_flag = 1;                           // Alarm Flag On
        end
        // Alarm Flag On & Seconds and Minutes not 0
        else if (set_flag && (sec != 0 || min != 0)) begin
            set_flag = 0;                           // Alarm Flag Clear
        end
        else if (btn_clear) begin
            start_set = 0;
            alarm = 0;
            set_flag = 0;
            set_sec = 0;
            set_min = 0;
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
                    if (sec == 0) begin             // 0 Seconds Pass
                        if (min) begin              // Minutes not 0
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
            else begin                              // State Stop & Set Mode
                if (inc_sec && alarm == 0) begin    // Input Increase Second Button & Alarm Off State
                    if(sec >= 59) begin             // 0 ~ 59 Second Set
                        sec = 0;
                    end
                    else begin
                        sec = sec + 1;              // Second Increase
                    end
                end
                if (inc_min && alarm == 0) begin    // Input Increase Minute Button & Alarm Off State
                    if (min >= 59) begin            // 0 ~ 59 Minute Set
                        min = 0;
                    end
                    else begin
                        min = min + 1;              // Minute Increase
                    end
                end
                if (set_flag) begin                 // Alarm Flag On
                    sec = set_sec;                  // Previous Second Set
                    min = set_min;                  // Previous Minute Set
                end
            end
            if (btn_clear) begin
                cnt_sysclk = 1;
                sec = 0;
                min = 0;
            end
        end
    end
endmodule

// Stop Watch Module
module stop_watch (
    input clk, reset_p,
    input btn_start, btn_lap, btn_clear,
    output [7:0] fnd_csec, fnd_sec,
    output reg start_stop, lap
    );
    
    reg [26:0] cnt_sysclk;                          // Clock Division Count
    reg [7:0] sec, csec;                            // HEX Format Time, Second, Subsecond
    reg [7:0] lap_sec, lap_csec;                    // Middle Record Time

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
        else if (btn_lap && (csec != 0 || sec != 0)) begin                     // Input Lap Button
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
            csec = 0;
            sec = 0;                                // Time Reset
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
                csec = 0;                           // Time Reset
                sec = 0;
            end
        end
    end

    // Determine FND Output by Middle Recode Mode
    assign fnd_csec = lap ? lap_csec : csec;
    assign fnd_sec = lap ? lap_sec : sec;
endmodule

// Humidity & Temperature Sensor data read & write, FSM
module dht11_cntr (
    input clk, reset_p,
    inout dht11_data,                           // Input + Output, reg Declaration Not Possible
    output reg [7:0] humidity, temperature,     // Output Measurement
    output [15:0] led                           // for Debugging
    );

    // Change State Using Shift
    localparam S_IDLE       = 6'b00_0001;       // Standby State
    localparam S_LOW_18MS   = 6'b00_0010;       // MCU Sends Out Start Signal
    localparam S_HIGH_20US  = 6'b00_0100;       // MCU Pull Up & Wait for Sensor Response
    localparam S_LOW_80US   = 6'b00_1000;       // DHT Sends Out Response Signal
    localparam S_HIGH_80US  = 6'b01_0000;       // DHT Pull Up & Get Ready Data
    localparam S_READ_DATA  = 6'b10_0000;       // DHT Data Read

    localparam S_WAIT_PEDGE = 2'b01;            // Start to Transmit 1-bit Data
    localparam S_WAIT_NEDGE = 2'b10;            // Voltage Length Measurement


    // Clock Divide 100, 10ns x 100 = 1us
    wire clk_usec_nedge;                        // Divide Clock 1us
    clock_div_100 us_clk (.clk(clk), .reset_p(reset_p), .nedge_div_100(clk_usec_nedge));

    // us Unit Count
    reg [21:0] cnt_usec;                        // us Count
    reg cnt_usec_e;                             // us Count Enable
    always @(negedge clk, posedge reset_p) begin
        if (reset_p) cnt_usec = 0;              // Count Clear
        else if (clk_usec_nedge && cnt_usec_e) begin    // Count Start when Enable & us Negative Edge
            cnt_usec = cnt_usec + 1;            // Count During Enable
        end
        else if (!cnt_usec_e) cnt_usec = 0;     // Count Clear when Disable
    end

    // Edge Detection of DHT Signal
    wire dht_nedge, dht_pedge;
    edge_detector_pos btn_ed (.clk(clk), .reset_p(reset_p),
        .cp(dht11_data), .p_edge(dht_pedge), .n_edge(dht_nedge));

    // Input Cannot be Declared as reg, Use Buffer
    reg dht11_buffer;                           // Buffer
    reg dht11_data_out_e;                       // Write Mode Enable Output, Disable Input
    assign dht11_data = dht11_data_out_e ? dht11_buffer : 'bz; // Output dout, Input Impedance Value

    reg [5:0] state, next_state;                // Current & Next State
    assign led [5:0] = state;                   // State LED Output
    reg [1:0] read_state;                       // Data Read State
    // Change State in Negative Edge
    always @(negedge clk, posedge reset_p) begin
        if (reset_p) state = S_IDLE;            // Basic Standby State
        else state = next_state;                // Change State in Negative Edge
    end

    reg [39:0] temp_data;                       // DHT Output Data 40-bit
    reg [5:0] data_cnt;                         // Counting to 40
    assign led [11:6] = data_cnt;
    // Set Next State in Positive Edge
    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin
            next_state = S_IDLE;                // Basic Stanby State
            temp_data = 0;                      // DHT Data Reset
            data_cnt = 0;                       // DHT Data Count Reset
            dht11_data_out_e = 0;               // DHT Write Disable, Input
            read_state = S_WAIT_PEDGE;          // Data Read Pull-Up High
        end
        else begin
            case (state)
                S_IDLE      : begin             // Standby State
                    if (cnt_usec < 22'd3_000_000) begin     // Real 3_000_000, Test 3_000
                        cnt_usec_e = 1;         // us Count Enable
                        dht11_data_out_e = 0;   // DHT Input Mode
                    end
                    else begin
                        cnt_usec_e = 0;         // Count Clear
                        next_state = S_LOW_18MS;// Change State S_LOW_18MS
                    end
                end
                S_LOW_18MS  : begin             // MCU Sends Out Start Signal
                    if (cnt_usec < 22'd18_000) begin    // Real 18_000, Test 18
                        cnt_usec_e = 1;         // us Count Enable
                        dht11_data_out_e = 1;   // DHT Output Mode
                        dht11_buffer = 0;       // Buffer Reset
                    end
                    else begin
                        cnt_usec_e = 0;         // us Count Disable, Clear
                        next_state = S_HIGH_20US;   // Change State S_HIGH_20US
                        dht11_data_out_e = 0;   // DHT Input Mode
                    end
                end
                // It is Supposed to Respond after 20us, but in Reality, Response Occurs before that.
                // Remove 20us Waiting Part
                S_HIGH_20US : begin             // MCU Pull Up & Wait for Sensor Response
                    cnt_usec_e = 1;             // Count for Checking Response Time
                    if (cnt_usec > 22'd100_000) begin   // No Response 100ms, Comunication Error, Etc..
                        cnt_usec_e = 0;         // us Count Disable, Clear
                        next_state = S_IDLE;    // Change State S_IDLE
                    end
                    if (dht_nedge) begin        // DHT Response, No Count
                        cnt_usec_e = 0;         // us Count Disable, Clear
                        next_state = S_LOW_80US;    // Change State S_LOW_80US
                    end
                end
                S_LOW_80US  : begin             // DHT Sends Out Response Signal
                    cnt_usec_e = 1;             // Count for Checking Response Time
                    if (cnt_usec > 22'd100_000) begin   // No Response 100ms, Comunication Error, Etc..
                        cnt_usec_e = 0;         // us Count Disable, Clear
                        next_state = S_IDLE;    // Change State S_IDLE
                    end
                    if (dht_pedge) begin
                        cnt_usec_e = 0;         // us Count Disable, Clear
                        next_state = S_HIGH_80US;    // No Need to Count, Change State
                    end
                end
                S_HIGH_80US : begin             // DHT Pull Up & Get Ready Data
                    cnt_usec_e = 1;             // Count for Checking Response Time
                    if (cnt_usec > 22'd100_000) begin   // No Response 100ms, Comunication Error, Etc..
                        cnt_usec_e = 0;         // us Count Disable, Clear
                        next_state = S_IDLE;    // Change State S_IDLE
                    end
                    if (dht_nedge) begin
                        cnt_usec_e = 0;         // us Count Disable, Clear
                        next_state = S_READ_DATA;    // No Need to Count, Change State
                    end
                end
                S_READ_DATA : begin             // DHT Data Read
                    case (read_state)
                        S_WAIT_PEDGE : begin    // Current Low, Wait High
                            // High Signal Generation
                            if (dht_pedge) read_state = S_WAIT_NEDGE;   // Change State
                            cnt_usec_e = 0;     // us Count Disable, Clear
                        end
                        S_WAIT_NEDGE : begin    // Current High, Wait Low
                            // Low Signal Generation
                            if (dht_nedge) begin
                                read_state = S_WAIT_PEDGE;              // Change State
                                data_cnt = data_cnt + 1;                // Counting to 40
                            if (cnt_usec < 50) begin        // Distinguish by Signal Length
                                    temp_data = {temp_data[38:0], 1'b0};    // Shift Left & Enter Value in LSM
                                end
                                else begin
                                    temp_data = {temp_data[38:0], 1'b1};
                                end
                            end
                            else begin
                                cnt_usec_e = 1;     // us Count Enable
                                if (cnt_usec > 22'd100_000) begin   // No Response 100ms, Comunication Error, Etc..
                                    cnt_usec_e = 0;         // us Count Disable, Clear
                                    next_state = S_IDLE;
                                    data_cnt = 0;           // DHT Data Count Reset
                                    read_state = S_WAIT_PEDGE;
                                end
                            end
                        end
                    endcase

                    if (data_cnt >= 40) begin   // 40-bit Read Completed
                        next_state = S_IDLE;    // Basic Stanby State
                        data_cnt = 0;           // DHT Data Count Reset
    // DHT11 Data = Humidity Integral 8-bit + Decimal 8-bit + Temperature Integral 8-bit + Decimal 8-bit + Check Sum 8-bit
                        // Compare Upper 32-bits of Sum with Checksum
                        if ((temp_data[39:32] + temp_data[31:24] + temp_data[23:16] + temp_data[15:8]) == temp_data[7:0]) begin
                            humidity = temp_data[39:32];        // Use only Integer Values
                            temperature = temp_data[23:16];
                        end
                    end
                end
                default : next_state = S_IDLE;  // Basic Stanby State
            endcase
        end
    end
endmodule

// Ultrasonic Sensor, FSM
module ultrasonic_cntr (
    input clk, reset_p,
    input ultra_echo,                           // Input Echo Pulse
    output reg ultra_trig,                      // Output Initiate Signal
    output reg [11:0] distance,                 // Distance Calculation
    output [15:0] led                           // for Debugging, State Output
    );
    
    // Change State Using Shift
    localparam S_IDLE   = 5'b0_0001;            // Standby State
    localparam S_TIRG_H = 5'b0_0010;            // Trig Pin High Signal Transmission
    localparam S_TIRG_L = 5'b0_0100;            // Trig Pin Low Signal Transmission
    localparam S_ECHO_H = 5'b0_1000;            // Echo Pin High Signal Reception
    localparam S_ECHO_L = 5'b1_0000;            // Echo Pin Low Signal Reception & Distance Calculation

    // Clock Divide 100, 10ns x 100 = 1us
    wire clk_usec_nedge;                        // Divide Clock 1us
    clock_div_100 us_clk (.clk(clk), .reset_p(reset_p), .nedge_div_100(clk_usec_nedge));

    // us Unit Count
    reg [21:0] cnt_usec;                        // us Count
    reg cnt_usec_e;                             // us Count Enable
    always @(negedge clk, posedge reset_p) begin
        if (reset_p) cnt_usec = 0;              // Count Clear
        else if (clk_usec_nedge && cnt_usec_e) begin    // Count Start when Enable & us Negative Edge
            cnt_usec = cnt_usec + 1;            // Count During Enable
        end
        else if (!cnt_usec_e) cnt_usec = 0;     // Count Clear when Disable
    end

    reg [21:0] div_usec_58;                        // 
    reg div_usec_58_e;                             // 
    reg [11:0] cnt_dist;
    always @(negedge clk, posedge reset_p) begin
        if (reset_p) begin
            div_usec_58 = 0;              // Count Clear
            cnt_dist = 0;
        end
        else if (clk_usec_nedge && div_usec_58_e) begin    // Count Start when Enable & us Negative Edge
            if (div_usec_58 >= 57) begin
                div_usec_58 = 0;
                cnt_dist = cnt_dist + 1;
            end
            else div_usec_58 = div_usec_58 + 1;            // Count During Enable
        end
        else if (!cnt_usec_e) begin
            div_usec_58 = 0;     // Count Clear when Disable
            cnt_dist = 0;
        end
    end

    // Edge Detection of Ultrasonic Echo Signal
    wire ultra_nedge, ultra_pedge;
    edge_detector_pos btn_ed (.clk(clk), .reset_p(reset_p),
        .cp(ultra_echo), .p_edge(ultra_pedge), .n_edge(ultra_nedge));

    reg [4:0] state, next_state;                // Current & Next State
    assign led [4:0] = state;                   // State LED Output
    assign led [5] = ultra_trig;                // Trig Signal LED Output
    assign led [6] = ultra_echo;                // Echo Signal LED Output
    // Change State in Negative Edge
    always @(negedge clk, posedge reset_p) begin
        if (reset_p) state = S_IDLE;            // Basic Standby State
        else state = next_state;                // Change State in Negative Edge
    end

    // reg [14:0] echo_time;                       // Echo Pulse Width
    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin
            next_state = S_IDLE;                // Basic Standby State
        end
        else begin
            case (state)
                S_IDLE   : begin                // Standby State
                    if (cnt_usec < 22'd200_000) begin   // Real 200_000, Test 1_000
                        cnt_usec_e = 1;         // us Count Enable
                    end
                    else begin
                        cnt_usec_e = 0;         // us Count Disable, Clear
                        next_state = S_TIRG_H;  // Change State S_TIRG_H
                    end
                end
                S_TIRG_H : begin                // Trig Pin High Signal Transmission
                    if (cnt_usec < 22'd10) begin    // Hold High Signal for 10us
                        cnt_usec_e = 1;         // us Count Enable
                        ultra_trig = 1;         // Trig Pin High Signal
                    end
                    else begin
                        cnt_usec_e = 0;         // us Count Disable, Clear
                        next_state = S_TIRG_L;  // Change State S_TIRG_L
                    end
                end
                S_TIRG_L : begin                // Trig Pin Low Signal Transmission
                    ultra_trig = 0;             // Trig Pin Low Signal
                    cnt_usec_e = 1;             // Count for Checking Response Time
                    if (cnt_usec > 22'd200_000) begin   // No Response 200ms, Error, Etc..
                        cnt_usec_e = 0;         // us Count Disable, Clear
                        next_state = S_IDLE;    // Change State S_IDLE
                    end
                    if (ultra_pedge) begin      // Check Echo High Signal
                        cnt_usec_e = 0;         // us Count Disable, Clear
                        div_usec_58_e = 1;
                        next_state = S_ECHO_H;
                    end
                end
                S_ECHO_H : begin                // Echo Pin High Signal Reception
                    cnt_usec_e = 1;             // us Count Enable
                    if (cnt_usec > 22'd25_000) begin   // No Response 25ms, Error, Etc..
                        cnt_usec_e = 0;         // us Count Disable, Clear
                        div_usec_58_e = 0;
                        next_state = S_IDLE;    // Change State S_IDLE
                    end
                    if (ultra_nedge) begin      // Check Echo Low Signal
                        // echo_time = cnt_usec;   // Echo Pulse Width Record, us
                        distance = cnt_dist;
                        next_state = S_ECHO_L;  // Change State S_ECHO_L
                    end
                end
                S_ECHO_L : begin                // Echo Pin Low Signal Reception
                    cnt_usec_e = 0;             // us Count Disable, Clear
                    div_usec_58_e = 0;
                    // distance = echo_time / 58;  // Distance Calculation
                    next_state = S_IDLE;        // Change State S_IDLE
                end
                default  : next_state = S_IDLE; // Basic Stanby State
            endcase
        end
    end
endmodule

// 4 x 4 Keypad, FSM
module keypad_cntr (
    input clk, reset_p,
    input [3:0] row,                            // Input Row Values when Column is High
    output reg [3:0] col,                       // Output High Values by Changing Column
    output reg [3:0] key_value,                 // Output Values According to Row and Column Inputs
    output reg key_valid,                       // Key Input Flag
    output [15:0] led                           // for Debugging
    );

    // Change State Using Shift
    localparam SCAN_0       = 5'b00001;         // Check Row Value of 1st Column
    localparam SCAN_1       = 5'b00010;         // Check Row Value of 2nd Column
    localparam SCAN_2       = 5'b00100;         // Check Row Value of 3rd Column
    localparam SCAN_3       = 5'b01000;         // Check Row Value of 4th Column
    localparam KEY_PROCESS  = 5'b10000;         // When Key Input

    assign led[0] = key_valid;
    assign led[4:1] = col;
    assign led[8:5] = row;

    reg [19:0] clk_10ms;                        // 2^20ns = 10_485_760ns, About 10ms
    always @(posedge clk) clk_10ms = clk_10ms + 1;

    wire clk_10ms_pedge, clk_10ms_nedge;
    // Edge Detection of 20th High-Order Clock bit
    edge_detector_pos ms_10_ed (.clk(clk), .reset_p(reset_p),
        .cp(clk_10ms[19]), .p_edge(clk_10ms_pedge), .n_edge(clk_10ms_nedge));

    // State Change Sequential Circuit
    reg [4:0] state, next_state;
    always @(posedge clk, posedge reset_p) begin
        if (reset_p) state = SCAN_0;            // Basic Check 1st Column
        else if (clk_10ms_pedge) state = next_state;    // Change State when 10ms Positive Edge 
    end

    // State Processing Combinational Circuit
    always @* begin                             // All Variables Detection, Combinational Circuit
        case (state)
            SCAN_0      : begin                         // Check 1st Column
                if (row == 0) next_state = SCAN_1;      // Row Value 0 → Change State SCAN_1
                else next_state = KEY_PROCESS;          // Check High in Any Row → Change State KEY_PROCESS
            end
            SCAN_1      : begin                         // Check 2nd Column
                if (row == 0) next_state = SCAN_2;      // Row Value 0 → Change State SCAN_2
                else next_state = KEY_PROCESS;          // Check High in Any Row → Change State KEY_PROCESS
            end
            SCAN_2      : begin                         // Check 3rd Column
                if (row == 0) next_state = SCAN_3;      // Row Value 0 → Change State SCAN_3
                else next_state = KEY_PROCESS;          // Check High in Any Row → Change State KEY_PROCESS
            end
            SCAN_3      : begin                         // Check 4th Column
                if (row == 0) next_state = SCAN_0;      // Row Value 0 → Change State SCAN_0
                else next_state = KEY_PROCESS;          // Check High in Any Row → Change State KEY_PROCESS
            end
            KEY_PROCESS : begin                         // When Key Input
                if (row == 0) next_state = SCAN_0;      // Change Row Value 0 → Change State SCAN_0
                else next_state = KEY_PROCESS;          // Check High in Any Row → Maintain State KEY_PROCESS
            end
            default : next_state = SCAN_0;              // Basic Check 1st Column
        endcase
    end

    // Function Implementation Sequential Circuit
    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin
            col = 4'b0001;                      // Basic 1st Column
            key_value = 0;                      // Key Value Reset
            key_valid = 0;                      // Key State Reset
        end
        else if (clk_10ms_nedge) begin          // Change Column of High Value when 10ms Negative Edge
            case (state)
                SCAN_0      : begin             // Check 1st Column
                    col = 4'b0001;              // 1st Column Output High
                    key_valid = 0;              // Basic Key Input Flag Clear
                end
                SCAN_1      : begin             // Check 2nd Column
                    col = 4'b0010;              // 2nd Column Output High
                    key_valid = 0;              // Basic Key Input Flag Clear
                end
                SCAN_2      : begin             // Check 3rd Column
                    col = 4'b0100;              // 3rd Column Output High
                    key_valid = 0;              // Basic Key Input Flag Clear
                end
                SCAN_3      : begin             // Check 4rd Column
                    col = 4'b1000;              // 4th Column Output High
                    key_valid = 0;              // Basic Key Input Flag Clear
                end
                KEY_PROCESS : begin             // When Key Input
                    key_valid = 1;              // Basic Key Input Flag Set
                    case ({row, col})           // Check Row and Column
                        8'b0001_0001 : key_value = 4'h0;    // 1st Row, 1st Column
                        8'b0001_0010 : key_value = 4'h1;    // 1st Row, 2nd Column
                        8'b0001_0100 : key_value = 4'h2;    // 1st Row, 3rd Column
                        8'b0001_1000 : key_value = 4'h3;    // 1st Row, 4th Column
                        8'b0010_0001 : key_value = 4'h4;    // 2nd Row, 1st Column
                        8'b0010_0010 : key_value = 4'h5;    // 2nd Row, 2nd Column
                        8'b0010_0100 : key_value = 4'h6;    // 2nd Row, 3rd Column
                        8'b0010_1000 : key_value = 4'h7;    // 2nd Row, 4th Column
                        8'b0100_0001 : key_value = 4'h8;    // 3rd Row, 1st Column
                        8'b0100_0010 : key_value = 4'h9;    // 3rd Row, 2nd Column
                        8'b0100_0100 : key_value = 4'hA;    // 3rd Row, 3rd Column
                        8'b0100_1000 : key_value = 4'hb;    // 3rd Row, 4th Column
                        8'b1000_0001 : key_value = 4'hC;    // 4th Row, 1st Column
                        8'b1000_0010 : key_value = 4'hd;    // 4th Row, 2nd Column
                        8'b1000_0100 : key_value = 4'hE;    // 4th Row, 3rd Column
                        8'b1000_1000 : key_value = 4'hF;    // 4th Row, 4th Column
                    endcase
                end
            endcase
        end
    end
endmodule
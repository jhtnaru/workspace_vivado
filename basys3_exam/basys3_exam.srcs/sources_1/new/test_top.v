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
    edge_detector_pos clk_div_edge (.clk(clk), .reset_p(reset_p), .cp(clk_div[18]), .p_edge(clk_div_18));

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
    input clk, reset_p,
    // input [2:0] btn,
    output [6:0] seg_7,
    output dp,
    output [3:0] com
    );

    // wire btn_mode, inc_sec, inc_min;
    // button_debounce btn_0 (.clk(clk), .noise_btn(btn[0]), .clean_btn(btn_mode));
    // button_debounce btn_1 (.clk(clk), .noise_btn(btn[1]), .clean_btn(inc_sec));
    // button_debounce btn_2 (.clk(clk), .noise_btn(btn[2]), .clean_btn(inc_min));

    reg [26:0] cnt_sysclk;                          // Clock 분주용
    reg [11:0] sec, min;                            // bcd to dec 맞춰 12-bit
    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin
            cnt_sysclk = 0;
            sec = 0;
            min = 0;
        end
        else begin
            if (cnt_sysclk >= 27'd100_000_000) begin    // 10ns x 100,000,000 = 1s
                cnt_sysclk = 0;
                if (sec >= 59) begin
                    sec = 0;
                    if (min >= 59) begin
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
            cnt_sysclk = cnt_sysclk + 1;
        end
    end

    wire [15:0] sec_bcd, min_bcd;
    bin_to_dec bcd_sec (.bin(sec), .bcd(sec_bcd));
    bin_to_dec bcd_min (.bin(min), .bcd(min_bcd));

    fnd_cntr fnd (.clk(clk), .reset_p(reset_p),
                .fnd_value({min_bcd[7:0], sec_bcd[7:0]}), .hex_bcd(1),
                .seg_7(seg_7), .dp(dp), .com(com));
endmodule


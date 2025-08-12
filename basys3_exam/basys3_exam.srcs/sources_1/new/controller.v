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
            cnt <= 0;           // Input == Before State, Stable State → Counter Reset
        end
        else begin
            cnt <= cnt + 1;     // Inpue != Before State, Count Increase
            if (cnt >= 1_000_000) begin  // Maintain a Specific Time for Debounce, 10ns * 1,000,000 = 10ms
                btn_state <= btn_sync_1;
                clean_btn <= btn_sync_1;
                cnt <= 0;
            end
        end
    end
endmodule

// Button Debounce + Edge Detect
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
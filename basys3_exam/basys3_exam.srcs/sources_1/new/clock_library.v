`timescale 1ns / 1ps

module clock_div_100 (
    input clk, reset_p,
    output reg clk_div_100,
    output nedge_div_100, pedge_div_100
    );

    reg [5:0] cnt_sysclk;

    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin
            cnt_sysclk = 0;
            clk_div_100 = 0;
        end
        else begin
            if (cnt_sysclk >= 49) begin
                cnt_sysclk = 0;
                clk_div_100 = ~clk_div_100;
            end
            else begin
                cnt_sysclk = cnt_sysclk + 1;
            end
        end
    end

    edge_detector_pos clk_ed (.clk(clk), .reset_p(reset_p),
        .cp(clk_div_100), .p_edge(pedge_div_100), .n_edge(nedge_div_100));
endmodule

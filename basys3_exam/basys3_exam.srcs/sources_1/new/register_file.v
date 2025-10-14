`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/01/2025 02:37:17 PM
// Design Name: 
// Module Name: register_file
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

//
module register_file (
    output [31:0] RD1, RD2,
    input [4:0] RR1, RR2, WR,
    input [31:0] WD,
    input RegWrite, clk, reset_p
    );

    reg [31:0] Register_file [0:31];

    assign RD1 = Register_file[RR1];
    assign RD2 = Register_file[RR2];

    always @(posedge clk) begin
        if (reset_p) begin // 원래 Memory Reset 안함
            Register_file [0]  = 0;
            Register_file [1]  = 0;
            Register_file [2]  = 0;
            Register_file [3]  = 0;
            Register_file [4]  = 0;
            Register_file [5]  = 0;
            Register_file [6]  = 0;
            Register_file [7]  = 0;
            Register_file [8]  = 0;
            Register_file [9]  = 0;
            Register_file [10] = 0;
            Register_file [11] = 0;
            Register_file [12] = 0;
            Register_file [13] = 0;
            Register_file [14] = 0;
            Register_file [15] = 0;
            Register_file [16] = 0;
            Register_file [17] = 0;
            Register_file [18] = 0;
            Register_file [19] = 0;
            Register_file [20] = 0;
            Register_file [21] = 0;
            Register_file [22] = 0;
            Register_file [23] = 0;
            Register_file [24] = 0;
            Register_file [25] = 0;
            Register_file [26] = 0;
            Register_file [27] = 0;
            Register_file [28] = 0;
            Register_file [29] = 0;
            Register_file [30] = 0;
            Register_file [31] = 0;
        end
        else if (RegWrite) begin
            if (WR) Register_file[WR] = WD; // 0번지는 0 유지
        end
    end
endmodule

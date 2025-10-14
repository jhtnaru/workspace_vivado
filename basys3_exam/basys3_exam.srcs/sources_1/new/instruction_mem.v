`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/01/2025 02:14:18 PM
// Design Name: 
// Module Name: instruction_mem
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
module instruction_mem (
    output [31:0] instruction,
    input [6:0] PC
    );

    reg [31:0] inst_reg [0:127];

    assign instruction = inst_reg[PC];
endmodule

//
// module instruction_mem (
//     output [31:0] instruction,
//     input clk,
//     input inst_wen,
//     input [31:0] inst_data,
//     input [6:0] PC, inst_addr
//     );

//     reg [31:0] inst_reg [0:127];

//     always @(posedge clk) begin
//         if (inst_wen) inst_reg[inst_addr] = inst_data;
//     end

//     assign instruction = inst_reg[PC];
// endmodule

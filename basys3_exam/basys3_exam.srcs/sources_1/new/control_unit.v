`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/02/2025 10:56:26 AM
// Design Name: 
// Module Name: control_unit
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
module control_unit (
    input [31:0] instruction,
    output [3:0] ALUSel
    );

    wire [8:0] inst_opcode = {instruction[30], instruction[14:12], instruction[6:2]};

    assign ALUSel = inst_opcode[8:5];
endmodule

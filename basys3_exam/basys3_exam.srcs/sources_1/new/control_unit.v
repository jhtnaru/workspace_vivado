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

// Instruction Decoder
module control_unit (
    input [31:0] instruction,
    output [3:0] ALUSel,
    output [2:0] ImmSel, // I 0, B 1, U 2, J 3, S 4
    output [2:0] WordSizeSel, // Byte 0, Half Word 1, Word 2
    output BSel, MemRW, WBSel
    );

    wire I_cond, B_cond, U_cond, J_cond, S_cond, R_cond;
    wire [8:0] inst_opcode = {instruction[30], instruction[14:12], instruction[6:2]};

    // opcode로 Type 구분
    assign I_cond = {inst_opcode[4:3], inst_opcode[1:0]} == 4'b0000;
    assign B_cond = inst_opcode[4:0] == 5'b11000;
    assign U_cond = {inst_opcode[4], inst_opcode[2:0]} == 4'b0101;
    assign J_cond = inst_opcode[4:0] == 5'b11011;
    assign S_cond = inst_opcode[4:0] == 5'b01000;
    assign R_cond = inst_opcode[4:0] == 5'b01100;
    
    assign ALUSel = inst_opcode[8:5];
    assign ImmSel = (I_cond == 1) ? 0 :
                    (B_cond == 1) ? 1 :
                    (U_cond == 1) ? 2 :
                    (J_cond == 1) ? 3 :
                    (S_cond == 1) ? 4 : 5;
    assign BSel = R_cond;
    assign MemRW = S_cond;
    assign WBSel = (inst_opcode[4:0] == 5'b00000) ? 0 : 1;
    assign WordSizeSel = inst_opcode[7:5];
endmodule

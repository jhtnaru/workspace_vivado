`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/13/2025 03:32:47 PM
// Design Name: 
// Module Name: ImmGen
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
module ImmGen(
    input [2:0] ImmSel, // 
    input [24:0] inst_Imm, // opcode(7) 제외한 25-bit
    output [31:0] Imm
    );

    wire [31:0] I, B, U, J, S;

    // 상위 20-bit는 inst_Imm[24]로 채움, 하위 12-bit는 inst_Imm 상위 12-bit 입력
    // inst_Imm = imm[11:0](12), rs1(5), funct3(3), rd(5)
    assign I = {{20{inst_Imm[24]}}, inst_Imm[24-:12]};

    // 짝수만 사용, 상위 19-bit는 inst_Imm[24]으로 채움, 하위 12-bit는 inst_Imm 조합, 최하위 bit는 0
    // inst_Imm = imm[12|10:5](7), rs2(5), rs1(5), funct3(3), imm[4:1|11](5)
    assign B = {{19{inst_Imm[24]}}, inst_Imm[24], inst_Imm[0], inst_Imm[23-:6], inst_Imm[4:1], 1'b0};

    // Upper, 상위 20-bit는 inst_Imm 상위 20-bit 입력, 하위 12-bit 0으로 채움
    // inst_Imm = imm[31:12](20), rd(5)
    assign U = {inst_Imm[24-:20], 12'b0};

    // 짝수만 사용, 상위 11-bit는 inst_Imm[24]으로 채움, 하위 20-bit는 inst_Imm 조합, 최하위 bit는 0
    // inst_Imm = imm[20|10:1|11|19:12](20), rd(5)
    assign J = {{11{inst_Imm[24]}}, inst_Imm[24], inst_Imm[12-:8], inst_Imm[13], inst_Imm[23-:10], 1'b0};

    // 상위 20-bit는 inst_Imm[24]로 채움, 하위 12-bit는 inst_Imm 조합
    // inst_Imm = imm[11:5](7), rs2(5), rs1(5), funct3(3), imm[4:0](5)
    assign S = {{20{inst_Imm[24]}}, inst_Imm[24-:7], inst_Imm[4:0]};

    assign Imm = (ImmSel == 0) ? I :
                 (ImmSel == 1) ? B :
                 (ImmSel == 2) ? U :
                 (ImmSel == 3) ? J :
                 (ImmSel == 4) ? S : 0;
endmodule

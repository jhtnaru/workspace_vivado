`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/01/2025 03:22:51 PM
// Design Name: 
// Module Name: ALU
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

module ALU (
    output [31:0] ALU_o,
    input signed [31:0] A, B, // 음수까지 읽는 32-bit 변수
    input [3:0] ALUSel
    );

    wire signed [31:0] ADD, SRA, SLL, SRL, XOR, AND, OR, SR;
    wire signed [31:0] B_compliment = ALUSel[3] ? ~B : B;
    wire [4:0] shamt = B[4:0];

    assign ADD = A + B_compliment + ALUSel[3]; // ALUSel[3] 0 이면 덧셈, 1 이면 뺄셈
    assign XOR = A ^ B;
    assign AND = A & B;
    assign OR  = A | B;
    assign SLL = A << shamt;
    assign SRL = A >> shamt;
    assign SRA = A >>> shamt; // >>> 음수일 경우 최상위 1을 채우면서 Right Shift
    assign SR  = ALUSel[3] ? SRA : SRL;

    assign ALU_o =
        (ALUSel == 0) ? ADD :
        (ALUSel == 1) ? XOR :
        (ALUSel == 2) ? AND : 0;
endmodule

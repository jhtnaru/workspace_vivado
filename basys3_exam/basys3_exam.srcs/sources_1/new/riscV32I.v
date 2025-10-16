`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/14/2025 12:19:18 PM
// Design Name: 
// Module Name: riscV32I
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
module riscV32I (
    input clk, reset_p
    );

    reg [6:0] PC;
    wire [6:0] PC_NEXT;

    assign PC_NEXT = PC + 1;

    always @(posedge clk, posedge reset_p) begin
        if (reset_p) PC = 0;
        else begin
            PC = PC_NEXT;
        end
    end

    wire [31:0] instruction;
    instruction_mem IMEM (.instruction(instruction), .PC(PC));

    wire [31:0] DataA, DataB;
    wire [31:0] WB, WB_Byte, WB_Half, WB_cut; // Write Back
    wire RegE;
    register_file REGFILE (.RD1(DataA), .RD2(DataB), .WD(WB_cut),
        .RR1(instruction[19:15]), .RR2(instruction[24:20]), .WR(instruction[11:7]),
        .RegWrite(RegE), .clk(clk), .reset_p(reset_p));

    wire [31:0] A, B, ALU_o, ALU_B;
    wire [3:0] ALUSel;
    ALU ALU_2 (.A(A), .B(ALU_B), .ALU_o(ALU_o), .ALUSel(ALUSel));

    wire [2:0] ImmSel, WordSizeSel;
    wire BSel, MemRW, WBSel;
    control_unit CNTR (.instruction(instruction), .ALUSel(ALUSel), .ImmSel(ImmSel),
        .BSel(BSel), .MemRW(MemRW), .WBSel(WBSel), .WordSizeSel(WordSizeSel));

    wire [31:0] Imm;
    ImmGen immgen (.ImmSel(ImmSel), .inst_Imm(instruction[31:7]), .Imm(Imm));

    wire [31:0] DMEM;
    data_mem DATAMEM (.ReadData(DMEM), .ADDR(ALU_o), .WriteData(DataB), .clk(clk), .MemWrite(MemRW));

    wire BrEq, BrLT, BrUn;
    BranchComp BrComp (.BrEq(BrEq), .BrLT(BrLT), .RD1(DataA), .RD2(DataB),
    .BrUn(BrUn)
    );

    assign WB = (WBSel == 1) ? ALU_o : DMEM;
    assign ALU_B = BSel ? B : Imm;
    assign WB_Byte = WordSizeSel[2] ? {24'b0, WB[7:0]}
                                    : {{24{WB[7]}}, WB[7:0]}; // 최상위 비트 24로 채운다 
    assign WB_Half = WordSizeSel[2] ? {16'b0, WB[15:0]}
                                    : {{16{WB[15]}}, WB[15:0]};
    assign WB_cut = (WordSizeSel[1:0] == 0) ? WB_Byte :
                    (WordSizeSel[1:0] == 1) ? WB_Half : WB;
endmodule
